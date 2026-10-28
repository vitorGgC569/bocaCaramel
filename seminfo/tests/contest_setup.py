"""Real native author/import/edit + isolated reference judge, synthetic data only."""
import argparse
import base64
import datetime as dt
import io
import json
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
import time
import urllib.request
import urllib.parse
from html.parser import HTMLParser
from unittest.mock import patch
from zipfile import ZipFile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import manage as kit
import organizer
import problems
from integration import fixtures, login


def multipart(fields,files):
    boundary='seminfo-'+secrets.token_hex(16)
    data=b''
    for name,value in fields.items():
        data+=f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
    for name,(filename,raw) in files.items():
        data+=f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{filename}"\r\nContent-Type: application/octet-stream\r\n\r\n'.encode()+raw+b'\r\n'
    return data+f'--{boundary}--\r\n'.encode(),'multipart/form-data; boundary='+boundary


def main(profile="si"):
    tag='seminfo-author-'+secrets.token_hex(5)
    names={k:tag+'-'+k for k in ('db','web','jail')};network=tag+'-net'
    lock=json.loads((kit.DIST/'server.lock.json').read_text())
    assert lock['source_sha256']==kit.source_hash()
    raw_run,raw_exists=kit.run,kit.exists
    actual_before={p:kit.fingerprint(f'boca-{p}-boca-db-1') for p in ('si','tii')}
    with tempfile.TemporaryDirectory() as temp:
        root=Path(temp);local=root/'local';(local/profile).mkdir(parents=True)
        cfg=json.loads((kit.HERE/'labs'/f'{profile}.json').read_text())
        cfg.update(start=(dt.datetime.now(dt.timezone.utc)-dt.timedelta(minutes=5)).isoformat(),
                   duration_minutes=120,freeze_minutes_before_end=0,timing_confirmed=True)
        credentials={key:secrets.token_hex(24) for key in ('POSTGRES_PASSWORD','BOCA_DB_PASSWORD','BOCA_PASSWORD','BOCA_KEY','SYSTEM_PASSWORD','SCORE_PASSWORD')}
        credentials.update({f'TEAM_{i:02}':secrets.token_hex(16) for i in range(1,11)})
        # Keep the saved user config on the real event date; only the disposable judge starts today.
        kit.write_json(local/profile/'lab.json',json.loads((kit.HERE/'labs'/f'{profile}.json').read_text()))
        kit.write_json(local/profile/'credentials.json',credentials)
        env=root/'isolated.env'
        env.write_text(''.join(k+'='+v+'\n' for k,v in credentials.items())+'SEMINFO_PROFILE='+profile+'\n')
        def control(selected,action,extra=None):
            assert selected==profile
            return json.loads(raw_run(['docker','exec','-i',names['web'],'php','/opt/seminfo/control.php',action],
                             data=json.dumps({'config':cfg,'credentials':credentials,**(extra or {})}).encode()))
        mapping={f'boca-{profile}-boca-db-1':names['db'],f'boca-{profile}-boca-web-1':names['web']}
        def mapped(args,**kwargs):
            def target(arg):
                value=str(arg)
                for old,new in mapping.items():
                    if value==old or value.startswith(old+':'):return new+value[len(old):]
                return arg
            return raw_run([target(a) for a in args],**kwargs)
        raw_run(['docker','network','create',network])
        try:
            raw_run(['docker','run','-d','--name',names['db'],'--network',network,'--network-alias','boca-db','--env-file',env,lock['images']['db']['reference']])
            kit.wait_database(names['db'])
            raw_run(['docker','run','-d','--name',names['web'],'--network',network,'--env-file',env,
                     '-e','BOCA_DB_HOST=boca-db','-e','BOCA_DB_SUPER_USER=postgres','-p','127.0.0.1::80',
                     '--entrypoint','/bin/bash',lock['images']['web']['reference'],'-c',
                     'export BOCA_DB_SUPER_PASSWORD="$POSTGRES_PASSWORD"; exec /opt/seminfo/server-init.sh'])
            for _ in range(90):
                if kit.inspect(names['web'])['State'].get('Health',{}).get('Status')=='healthy':break
                time.sleep(1)
            else:raise RuntimeError('Authoring test web not healthy')
            assert control(profile,'prepare')['ok']
            port=kit.inspect(names['web'])['NetworkSettings']['Ports']['80/tcp'][0]['HostPort']
            base=f'http://127.0.0.1:{port}/boca/'
            client=login(base,'admin',credentials['BOCA_PASSWORD'],'admin',contest=1)
            with client.open(base+'index.php?contest=1&destination=builder') as response:
                assert response.url.endswith('admin/buildproblem.php')
                assert b'Gerar ZIP' in response.read()
            with client.open(base+'index.php?contest=1&destination=problems') as response:
                assert response.url.endswith('admin/problem.php')
            # Exercise the translated buttons using the actual name/value emitted
            # by the rendered form; preserve the site's initial login setting.
            class Buttons(HTMLParser):
                def __init__(self):
                    super().__init__(); self.active=None; self.labels={}
                def handle_starttag(self,tag,attrs):
                    if tag=='button': self.active=(dict(attrs),[])
                def handle_data(self,data):
                    if self.active: self.active[1].append(data)
                def handle_endtag(self,tag):
                    if tag=='button' and self.active:
                        attrs,parts=self.active; self.labels[''.join(parts).strip()]=attrs; self.active=None
            page=client.open(base+'admin/site.php?site=1').read().decode('utf-8')
            buttons=Buttons(); buttons.feed(page)
            login_sql="SELECT sitepermitlogins FROM sitetable WHERE contestnumber=1 AND sitenumber=1"
            def login_state():
                return raw_run(['docker','exec',names['db'],'psql','-U','postgres','-d','bocadb','-Atc',login_sql]).decode().strip()
            initial=login_state()
            assert initial in ('t','f'),initial
            # Force the stored version ahead of the current second to reproduce
            # consecutive local changes deterministically, even on slower hosts.
            raw_run(['docker','exec',names['db'],'psql','-U','postgres','-d','bocadb','-c',
                     "UPDATE sitetable SET updatetime=extract(epoch from now())::bigint+10 WHERE contestnumber=1 AND sitenumber=1"])
            for label,expected in [('Desabilitar acessos','f'),('Habilitar acessos','t')]+([('Desabilitar acessos','f')] if initial=='f' else []):
                button=buttons.labels[label]
                assert button['name']=='Logins'
                data=urllib.parse.urlencode({'site':'1','confirmation':'confirm',button['name']:button['value']}).encode()
                client.open(urllib.request.Request(base+'admin/site.php?site=1',data),timeout=30).read()
                assert login_state()==expected,(label,login_state())
            print('Botões traduzidos de acesso: desabilitar e habilitar OK',flush=True)
            def post(fields,files):
                data,kind=multipart(fields,files)
                with client.open(urllib.request.Request(base+'admin/problem.php',data,{'Content-Type':kind}),timeout=30) as response:return response.read()
            def build(answer=b'42\n'):
                fields={'SubmitWizard':'Gerar ZIP','fullname':'Soma sintetica','basename':'A',
                        'time_limit':'2','memory_limit':'512','output_limit':'1024','repetitions':'1',
                        'statement_mode':'latex','latex_title':'Soma sintética',
                        'latex_description':'Some dois números.', 'latex_input':'Dois inteiros.',
                        'latex_output':'A soma.', 'case_input[]':'20 22\n',
                        'case_output[]':answer.decode(), 'case_visibility[]':'public'}
                data,kind=multipart(fields,{})
                with client.open(urllib.request.Request(base+'admin/buildproblem.php',data,{'Content-Type':kind}),timeout=60) as response:
                    package=response.read()
                with ZipFile(io.BytesIO(package)) as archive:
                    assert archive.read('description/statement.pdf').startswith(b'%PDF')
                    for ext in ('c','cpp','java','py3'):
                        for stage in ('compile','run','compare','limits'):assert stage+'/'+ext in archive.namelist()
                return package
            def publish(package):
                post({'Submit3':'Send','confirmation':'confirm','noflush':'true','problemnumber':'1','problemname':'A',
                      'colorname':'Amarelo','color':'ffcc00','autojudge_new_sel':'all'}, {'probleminput':('A.zip',package)})
                # BOCA fills metadata by reading problem.info when the list is rendered.
                client.open(base+'admin/problem.php').close()
            package=build();publish(package)
            with patch.object(kit,'LOCAL',local),patch.object(kit,'run',mapped),patch.object(kit,'exists',side_effect=lambda x:raw_exists(mapping.get(str(x),x))),patch.object(kit,'control',side_effect=control),patch('admission_setup.running',return_value=False):
                problem=problems.catalog(profile)[0]
                assert problem['basename']=='A' and problem['title']=='Soma sintetica'
                fixtures(root)
                refs=[{'name':name,'content':base64.b64encode((root/name).read_bytes()).decode()} for name in ('Main.c','Main.cpp','A.java','Main.py3')]
                before=kit.fingerprint(names['db'])
                good=problems.validate(profile,{'problem':1,'revision':problem['revision'],'sources':refs})
                if not good['passed']:kit.write_json(kit.HERE/'reports/contest-setup-reference-debug.json',good)
                assert good['passed'] and good['complete'],good['results']
                assert kit.fingerprint(names['db'])==before,'Reference run changed preparation database'
                assert problems.assert_reviewable(profile)
                print('Native builder/import and four accepted reference languages: OK',flush=True)
                # Edit the package through the same admin importer; prior success must expire.
                time.sleep(1.1)
                publish(build(b'99\n'))
                changed=problems.catalog(profile)[0]
                assert changed['revision']!=problem['revision']
                assert not problems.read_report(profile,changed)['current']
                wrong=[{'name':'Wrong.c','content':base64.b64encode((root/'Wrong.c').read_bytes()).decode()}]
                before=kit.fingerprint(names['db'])
                bad=problems.validate(profile,{'problem':1,'revision':changed['revision'],'sources':wrong})
                assert not bad['passed'] and not bad['complete'],bad
                assert kit.fingerprint(names['db'])==before
                # The normal bank backup must recover reference sources/reports too.
                with patch.object(kit,'HERE',root/'backup-kit'):
                    backup=kit.backup(profile)
                    kit.check_restore(backup)
                    manifest=json.loads((backup/'manifest.json').read_text())
                    assert set(manifest['reference_files_sha256'])=={'1/sources.json','1/validation.json'}
                    checked=json.loads((backup/'restore-verified.json').read_text())
                    assert checked['reference_files_sha256']==manifest['reference_files_sha256']
                assert control(profile,'activate')['ok']
                for _ in range(60):
                    if kit.inspect(names['web'])['State'].get('Health',{}).get('Status')=='healthy':break
                    time.sleep(1)
                port=kit.inspect(names['web'])['NetworkSettings']['Ports']['80/tcp'][0]['HostPort']
                base=f'http://127.0.0.1:{port}/boca/'
                client=login(base,'admin',credentials['BOCA_PASSWORD'],'admin',contest=1)
                # A mutation attempted against an active event must be ignored by the native page.
                before=problems.catalog(profile)
                publish(package)
                assert problems.catalog(profile)==before,'Active contest package was modified'
                # Exercise the same multipart form used by a real team, not
                # the organizer-only reference seeding API. The edited package
                # expects 99; send one correct and one incorrect C solution.
                raw_run(['docker','run','-d','--privileged','--name',names['jail'],
                         '--network',network,'--network-alias','boca-jail','--env-file',env,
                         '-e','BOCA_DB_HOST=boca-db','-e','BOCA_JAIL_HOST=boca-jail',
                         lock['images']['jail']['reference']])
                team=login(base,profile+'01',credentials['TEAM_01'],'team')
                # Create a real support request and verify both the translated
                # display and unchanged internal states through completion.
                request=urllib.parse.urlencode({'Submit':'S.O.S.','confirmation':'confirm'}).encode()
                team.open(urllib.request.Request(base+'team/task.php',request),timeout=30).read()
                sql="SELECT tasknumber FROM tasktable WHERE contestnumber=1 AND taskdesc='Staff assistance' ORDER BY tasknumber DESC LIMIT 1"
                number=raw_run(['docker','exec',names['db'],'psql','-U','postgres','-d','bocadb','-Atc',sql]).decode().strip()
                assert number.isdecimal(),number
                page=team.open(base+'team/task.php').read().decode('utf-8')
                assert 'Solicitação de ajuda' in page and 'Aguardando' in page
                page=client.open(base+'admin/task.php').read().decode('utf-8')
                assert 'Solicitação de ajuda' in page and 'Aguardando' in page
                client.open(base+'admin/task.php?get='+number+'&site=1').read()
                page=team.open(base+'team/task.php').read().decode('utf-8')
                assert 'Em atendimento' in page
                client.open(base+'admin/task.php?done='+number+'&site=1').read()
                page=team.open(base+'team/task.php').read().decode('utf-8')
                assert 'Concluído' in page
                print('Pedido de ajuda: equipe, atendimento e conclusão OK',flush=True)
                # Clarification status labels must not alter the stored BOCA code.
                payload=urllib.parse.urlencode({'message':'Dúvida de teste','problem':'1','Submit':'Enviar','confirmation':'confirm'}).encode()
                team.open(urllib.request.Request(base+'team/clar.php',payload),timeout=30).read()
                sql="SELECT clarnumber FROM clartable WHERE contestnumber=1 ORDER BY clarnumber DESC LIMIT 1"
                number=raw_run(['docker','exec',names['db'],'psql','-U','postgres','-d','bocadb','-Atc',sql]).decode().strip()
                assert number.isdecimal(),number
                page=client.open(base+'admin/clar.php').read().decode('utf-8')
                assert 'Aguardando resposta' in page and 'Ainda sem resposta' in page
                payload=urllib.parse.urlencode({'answer':'Resposta de teste','Submit':'Answer','number':number,'sitenumber':'1','confirmation':'confirm'}).encode()
                client.open(urllib.request.Request(base+'admin/claredit.php',payload),timeout=30).read()
                page=team.open(base+'team/clar.php').read().decode('utf-8')
                assert 'Resposta de teste' in page
                page=client.open(base+'admin/clar.php').read().decode('utf-8')
                assert 'Respondida' in page
                print('Dúvida: envio, estado e resposta OK',flush=True)
                for filename,source in [('correta.c',b'#include <stdio.h>\nint main(){puts("99");}\n'),
                                        ('errada.c',b'#include <stdio.h>\nint main(){puts("0");}\n')]:
                    payload,kind=multipart({'problem':'1','language':'1','Submit':'Send','confirmation':'confirm'},
                                           {'sourcefile':(filename,source)})
                    team.open(urllib.request.Request(base+'team/run.php',payload,{'Content-Type':kind}),timeout=30).read()
                query="SELECT coalesce(json_agg(r ORDER BY runnumber),'[]'::json) FROM (SELECT runnumber,runfilename,runstatus,runanswer FROM runtable WHERE contestnumber=1 ORDER BY runnumber) r"
                for _ in range(120):
                    rows=json.loads(raw_run(['docker','exec',names['db'],'psql','-U','postgres','-d','bocadb','-Atc',query]))
                    if len(rows)==2 and all(r['runstatus']=='judged' for r in rows): break
                    time.sleep(2)
                else: raise AssertionError('Submissões da equipe não foram julgadas: '+str(rows))
                assert [r['runfilename'] for r in rows]==['correta.c','errada.c'],rows
                answer_query="SELECT shortname FROM answertable WHERE contestnumber=1 AND answernumber="
                verdicts=[raw_run(['docker','exec',names['db'],'psql','-U','postgres','-d','bocadb','-Atc',answer_query+str(int(r['runanswer']))]).decode().strip() for r in rows]
                print('Envio HTTP da equipe: '+str(verdicts),flush=True)
                assert 'Julgada' in client.open(base+'admin/run.php').read().decode('utf-8')
                assert int(rows[0]['runanswer']) == 1 and int(rows[1]['runanswer']) == 6, rows
                team_page=team.open(base+'team/run.php').read().decode('utf-8')
                assert 'correta.c' in team_page and 'errada.c' in team_page
                print('Submissões e resultados visíveis para a equipe: OK',flush=True)
                report={'passed':True,'server_source_sha256':kit.source_hash(),'native_create_import_edit':True,
                        'cpp20_template':True,'references_four_languages':good['results'],
                        'wrong_reference_rejected':True,'changed_package_invalidates_validation':True,
                        'active_native_problem_edit_rejected':True,'disposable_preparation_database_unchanged_by_references':True,
                        'reference_sources_and_reports_backed_up_and_restore_checked':True,
                        'real_event_databases_unchanged':True,'utc':dt.datetime.now(dt.timezone.utc).isoformat()}
            assert all(kit.fingerprint(f'boca-{p}-boca-db-1')==actual_before[p] for p in ('si','tii'))
            kit.write_json(kit.HERE/'reports/contest-setup.json',report)
            print('PASSOU: criacao, importacao, edicao, referencias AC/WA, revisoes e bancos reais intactos.',flush=True)
        finally:
            for name in names.values():subprocess.run(['docker','rm','-f','-v',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            subprocess.run(['docker','network','rm',network],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--profile',choices=('si','tii'),default='si')
    main(parser.parse_args().profile)
