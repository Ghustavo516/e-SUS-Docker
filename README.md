# e-SUS APS — Docker (pull-and-run)

## Uso para quem já tem a imagem publicada

```bash
docker compose up -d
docker logs -f esus_server
```

Isso é tudo. O container instala o e-SUS (só na 1ª subida), gera o
certificado HTTPS, ajusta o PostgreSQL interno e sobe a aplicação
sozinho. Acompanhe cada etapa com `docker logs -f esus_server`.

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
docker compose up --build -d
```

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

- 1 único script (`entrypoint.sh`) faz tudo: instalação, certificado,
  Postgres, checagem de DNS/proxy, sobe a app e termina em `tail -f` dos
  próprios logs — por isso `docker logs` mostra tudo, sem serviço extra.
- 1 único `.service` do systemd, sem arquivos soltos.
- Sem `.env`: tudo fixo no topo do `entrypoint.sh` (host, senha da
  keystore) e no `docker-compose.yml` (portas).
- Dados, banco e certificados moram todos dentro do volume nomeado
  `esus_data` (mapeado para `/opt/e-SUS`, que já é onde o instalador
  grava tudo) — nada solto na raiz do projeto.
