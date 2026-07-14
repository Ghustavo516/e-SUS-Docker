# e-SUS APS — Docker (pull-and-run)

## Uso para quem já tem a imagem publicada

Um único comando, em um único terminal, do início ao fim:

```bash
./setup.sh
```

O script sobe o container, espera o serviço interno ficar de pé e **já
chama o instalador na hora, na mesma janela**. O instalador roda em
modo automático: você vê todo o wizard rolando na tela normalmente,
mas a pergunta de confirmação (S/N) já é respondida sozinha, sem
precisar apertar tecla nenhuma. Assim que o instalador termina, o
próprio `setup.sh` continua sozinho mostrando os logs: o container
detecta que a instalação acabou e continua automaticamente — gera o
certificado HTTPS, importa no truststore, ajusta o PostgreSQL (acesso
via DBeaver) e sobe a aplicação.

Se preferir fazer isso na mão em vez de usar o `setup.sh`, os mesmos
passos funcionam separadamente:

```bash
docker compose up -d
docker exec -it esus_server /opt/run-installer.sh   # instalador interativo
docker logs -f esus_server                          # acompanha a config automática
```

Depois de ver a linha "Pronto." no log:

1. No `/etc/hosts` da sua máquina (fora do Docker):
   `127.0.0.1 esusserver.local`
2. Acesse: `https://esusserver.local:8443`
3. Em "Configurações da Instalação > Link da instalação", use a porta
   **443** (não 8443).

## Build local (antes de publicar)

O instalador vem de um link do Google Drive (compartilhado como "qualquer
pessoa com o link"), baixado automaticamente durante o `docker build` via
`gdown` — não precisa colocar o `.jar` na pasta do projeto.

```bash
./setup.sh
```

(o `docker compose up -d` dentro do `setup.sh` builda automaticamente
quando a imagem ainda não existe localmente — não precisa de `--build`
manual.)

Se um dia trocar de versão do e-SUS, é só trocar o ID do arquivo do Drive
e o nome do instalador nos build-args do `docker-compose.yml`:

```yaml
build:
  context: .
  args:
    DRIVE_FILE_ID: "novo_id_do_drive"
    INSTALADOR_NAME: "eSUS-AB-PEC-x.x.x-Linux64"
```

## Publicar no Docker Hub

```bash
docker build -t seu-usuario/esus-server:5.4.38 .
docker push seu-usuario/esus-server:5.4.38
```

Depois, troque no `docker-compose.yml` a seção `build` por:
```yaml
image: seu-usuario/esus-server:5.4.38
```

e qualquer pessoa roda só com `docker compose up -d`.

**Atenção:** o instalador do e-SUS é um software de terceiros
(Ministério da Saúde). Confirme se redistribuí-lo embutido numa imagem
pública no Docker Hub está de acordo com os termos de uso antes de
publicar.

## O que mudou de manutenção

- O `setup.sh` agora faz tudo em **um único terminal**: sobe o
  container, espera o serviço interno ficar pronto e já dispara o
  instalador na mesma janela — não precisa mais abrir um segundo
  terminal para o `docker exec -it`.
- O `run-installer.sh` agora responde sozinho a pergunta de confirmação
  (S/N) do instalador (via `yes S | java -jar ...`) — você continua
  vendo o wizard rodando na tela em tempo real, só não precisa mais
  apertar tecla nenhuma. Se um dia o instalador de uma versão nova
  tiver perguntas diferentes, vale conferir se elas também podem ser
  respondidas com "S" antes de confiar cegamente no automático.
- Tudo o resto é automático dentro do `entrypoint.sh`: espera você
  instalar, gera certificado, importa no truststore, ajusta o Postgres,
  checa DNS/proxy, sobe a app, e termina em `tail -f` dos próprios logs
  — por isso `docker logs` mostra tudo, sem serviço extra.
- 1 único `.service` do systemd, sem arquivos soltos.
- Sem `.env`: tudo fixo no topo do `entrypoint.sh` (host, senha da
  keystore) e no `docker-compose.yml` (portas).
- Dados, banco e certificados moram todos dentro do volume nomeado
  `esus_data` (mapeado para `/opt/e-SUS`, que já é onde o instalador
  grava tudo) — nada solto na raiz do projeto.
