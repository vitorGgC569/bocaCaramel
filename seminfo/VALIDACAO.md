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

## Evidências automatizadas de 28/10/2026

As imagens do servidor foram reconstruídas preservando a correção de compilação Java do PR #1. O juiz usa o JDK instalado fora do chroot; a construção verifica C, C++ e Python dentro dele. A imagem-base contém pacotes Java parcialmente configurados no banco dpkg do chroot, por isso não se executa apt naquele ambiente durante a construção. Os executáveis e o julgamento precisam continuar sendo verificados sempre que a imagem-base mudar.

- Os 56 testes de unidade passaram; os testes isolados de rede e autorização aprovaram isolamento IPv4/IPv6, TLS e revogação.
- O fluxo sintético de criação, importação, quatro referências e envio pela equipe passou em SI e TII, incluindo resultados YES e WA, sem alterar os bancos reais. Após esse ensaio foram alterados apenas rótulos de interface; os testes de unidade e a geração dos gráficos foram repetidos.
- O ensaio ampliado de cada categoria processou 47 submissões de dez equipes, nas quatro linguagens, com resultados esperados para acerto, erro, compilação e tempo; também conferiu placar, congelamento e restauração.
- As ISOs atualizadas de SI e TII passaram na inspeção estática das identidades, banners por perfil, initramfs e boot híbrido. Os hashes e caminhos constam no README. As originais de 17/10 continuam preservadas.
- As imagens atuais passaram na verificação automática das duas categorias; SI foi iniciada em preparação nesta máquina e os bancos permaneceram iguais aos anteriores. A troca temporária de SI para TII e de volta foi testada antes do último ajuste textual.
- Gráficos de pizza e barras foram renderizados com PHP/GD. O teste reproduzível está em `seminfo/tests/chart-smoke.php` e deve ser executado dentro da imagem web com o arquivo montado em `/tests`.
- O bundle offline foi reconstruído e seu SHA-256, suas quatro imagens e o manifesto foram conferidos. Um clone público de `main` teve seus hashes de servidor e cliente comparados à instalação e ao pacote; os dois coincidiram. Antes da distribuição, confira `seminfo/dist/server-bundle.json` e `server.lock.json`. A pasta privada e os backups não são públicos.

Na revisão posterior do placar, acesso e tela do juiz, os 56 testes de unidade passaram novamente. A nova imagem foi verificada para SI e TII; em TII, o fluxo isolado repetiu a criação e importação de questão, as quatro referências, o envio HTTP com resultados YES e WA e a restauração de backup. A preparação de SI foi atualizada e o banco permaneceu intacto. O pacote offline e seu manifesto foram conferidos contra as fontes.

Na revisão seguinte, os botões administrativos e de julgamento foram traduzidos preservando os valores enviados aos formulários. O ensaio isolado de TII verificou os botões de habilitar e desabilitar acessos com versões consecutivas no mesmo segundo; uma correção no BOCA impede que a segunda alteração local seja ignorada. O ensaio repetiu criação e importação, quatro referências, backup e restauração, e submissões HTTP com YES e WA. Os 56 testes de unidade e a verificação de sintaxe PHP passaram.

Essas evidências não homologam as salas físicas. Os seis ensaios a seguir devem ser realizados presencialmente em cada laboratório; não registre atestados sem executá-los.

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
