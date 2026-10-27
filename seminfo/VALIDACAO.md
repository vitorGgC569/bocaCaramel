# Validação antes de 29/10/2026

Não marcar um teste como aprovado por existir um script. Resultados automatizados ficam em `seminfo/reports`; confirmações presenciais ficam em `seminfo/local/PERFIL/attestations.json`, vinculadas à configuração e ao código do servidor.

```powershell
python -m unittest discover -s seminfo/tests -v
python seminfo/tests/integration.py
python seminfo/tests/network.py
python seminfo/tests/admission_network.py
python seminfo/manage.py verify si
python seminfo/manage.py restore-check --backup "C:\caminho\backup"
```

A integração usa containers/rede próprios e problema sintético de soma. Autentica admin, placar e dez equipes, submete nas quatro linguagens e casos WA/CE/TLE e confere exportação contra BOCA. Os pacotes reais da Cristiane não entram nesse teste ou na distro.

O teste de rede usa `seminfo/client-builder:22.04`, quatro containers próprios e nftables real. Confere BOCA correto, outra porta da mesa, outro BOCA, equipe vizinha, loopback, IPv6, reaplicação e bloqueio após JSON inválido. Não altera o firewall do Windows. A rede física e o firewall das mesas continuam exigindo homologação presencial.

O ensaio `admission_network.py` usa bancas/clientes isolados, certificados reais, fila, código de aprovação, gate HTTP GET/POST e nftables. Confere revogação, certificado de outro laboratório, token de projetor impedido de aprovar, identidade root 0600 e expiração no kernel após matar o agente sem limpeza. Também consulta duas bancas e renderiza os placares de categorias separadas com questões, tempos e fases diferentes. A integração BOCA verifica igualdade do placar público, ocultação após freeze e bloqueio da publicação final antes do fim/com pendências.

## Uma ficha presencial por laboratório

| Registro | Evidência exigida |
|---|---|
| `client_boot` | PC/USB identificados; boot sem internet; arte fixa da categoria (TII claro/JUNIOR; SI espresso/PLENO), inclusive após reiniciar; janela com IP; icpc sem sudo; quatro linguagens |
| `client_persistence` | Arquivo em ~/trabalhos permanece depois de desligar/ligar sem depender do disco interno |
| `network_isolation` | Pendente bloqueado; código inválido recusado; BOCA correto após aprovação; revogação/queda/expiração; outro BOCA, PC vizinho e internet IPv4/IPv6 bloqueados; reboot exige nova aprovação; firewall/Agendador Windows reais |
| `projector` | Área estendida; placares separados SI/TII iguais ao respectivo BOCA; administrador não aparece; freeze, falha de outra banca e publicação final independentes; revelação por categoria |
| `judge_load` | Dez equipes; AC/WA/CE/TLE; fila se esvazia; limites adequados ao hardware real |
| `problems_reviewed` | Cada pacote real importado/julgado com solução correta/incorreta nas linguagens permitidas |

Registrar operador, PC, mídia e resultado com `manage.py attest`. Alterar IPs, duração, freeze ou código invalida os registros; conferir novamente a configuração final. Confirmar disponibilidade presencial até 28/10; o roteiro antigo não reserva laboratório.

Replicar os nove USBs restantes somente depois de o piloto passar. Conferir cada gravação, etiquetar lab/perfil e reservar um sobressalente por sala. Manter backup e credenciais protegidos com a organização. Antes de abrir as salas, conferir relógio das mesas, IPs reservados, duração e login das equipes.
