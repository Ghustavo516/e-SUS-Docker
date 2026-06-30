# e-SUS PEC Containerizado

Infraestrutura automatizada e containerizada para instalar e rodar o servidor **e-SUS APS PEC** localmente, utilizando **Docker**, **Docker Compose** e **Caddy** como proxy reverso para garantir comunicação HTTPS e isolamento do ambiente.

---

## ⚠️ Pré-requisito Importante: O Instalador do e-SUS

**O arquivo `.jar` do instalador do e-SUS NÃO está incluído neste repositório.**

Devido ao tamanho e às questões de versionamento, é necessário baixar o instalador oficial e posicioná-lo na **raiz** deste projeto antes de executar qualquer script.

1. Baixe o instalador do e-SUS PEC (ex: `eSUS-AB-PEC-5.4.38-Linux64.jar`) na página oficial do Ministério da Saúde:
   👉 https://sisaps.saude.gov.br/sistemas/esusaps/blog/versao-5-4-8/

2. Mova o arquivo `.jar` para a raiz do projeto (mesmo nível do arquivo `docker-compose.yml`).

3. Certifique-se de que o nome do arquivo (sem a extensão `.jar`) coincida exatamente com o valor definido na variável `INSTALADOR_NAME` no seu arquivo `.env`.

---

## Estrutura do Projeto

| Arquivo | Descrição |
|---|---|
| `setup.sh` | Script principal que orquestra a criação de diretórios, geração de certificados SSL locais, build da imagem e execução do instalador interativo. |
| `docker-compose.yml` | Define os serviços (`esus` e `caddy`), mapeamento de portas, redes e persistência de dados (volumes). |
| `Dockerfile` | Configura a imagem base (Ubuntu + systemd), instala dependências (Java, OpenSSL legado, locales) e prepara o ambiente para o e-SUS. |
| `caddy/Caddyfile` | Configura o proxy reverso para garantir comunicação HTTPS via domínio local. |
| `.env` | Arquivo de variáveis de ambiente do projeto (porta, host e nome do instalador). |

---

## Configuração do Ambiente (`.env`)

Crie um arquivo `.env` na raiz do projeto com o seguinte conteúdo:

```env
ESUS_PORT=8083
HTTPS_PORT=8989
HOST=minhaapp.local
INSTALADOR_NAME=eSUS-AB-PEC-5.4.38-Linux64
```

| Variável | Descrição | Padrão se omitida |
|---|---|---|
| `ESUS_PORT` | Porta externa de acesso HTTP ao servidor e-SUS | `8080` |
| `HTTPS_PORT` | Porta externa de acesso HTTPS (via Caddy) | `8080` |
| `HOST` | Domínio local usado para acessar a aplicação e gerar o certificado SSL | `minhaapp.local` |
| `INSTALADOR_NAME` | Nome do arquivo `.jar` do instalador (sem a extensão), usado no build da imagem | — (obrigatório) |

> 💡 As portas dos serviços podem ser customizadas através do arquivo `.env`. Caso não sejam definidas, a porta padrão `8080` é adotada.

---

## Como Iniciar

### 1. Clone o repositório

```bash
git clone <url-do-seu-repositorio>
cd <nome-da-pasta>
```

### 2. Adicione o instalador

Coloque o arquivo `.jar` baixado na raiz do projeto (veja a seção de [pré-requisitos](#️-pré-requisito-importante-o-instalador-do-e-sus)).

### 3. Configure o ambiente

Crie o arquivo `.env` na raiz do projeto conforme descrito em [Configuração do Ambiente](#configuração-do-ambiente-env).

### 4. Execute o setup

```bash
chmod +x setup.sh
./setup.sh
```

O script `setup.sh` irá:

1. Criar os diretórios `./data` e `./caddy`;
2. Gerar certificados SSL autoassinados para o Caddy;
3. Construir a imagem e subir os containers (`docker compose up --build -d`);
4. Aguardar a inicialização do sistema;
5. Executar o instalador interativo do e-SUS dentro do container.

### 5. Acompanhe a instalação

O script abrirá o console interativo do instalador diretamente no seu terminal. Siga os passos exibidos na tela até a conclusão.

Ao final, a aplicação estará disponível em:

```
https://minhaapp.local
```

> O domínio exibido corresponde ao valor configurado em `HOST` no arquivo `.env`.

---

## Persistência de Dados

O banco de dados e os arquivos do e-SUS são salvos na pasta `./data` local, mapeada como volume no container. Isso garante que os dados **não sejam perdidos** ao reiniciar ou recriar o container.

---

## Observações

- O container `esus` é executado em modo `privileged` com acesso ao cgroup do host, necessário para o funcionamento do `systemd` dentro do container.
- O Caddy atua como proxy reverso, expondo as portas `80` e `443` e redirecionando o tráfego HTTPS para o serviço e-SUS internamente.
