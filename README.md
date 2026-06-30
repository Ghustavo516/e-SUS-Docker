# e-SUS PEC Containerizado

Este projeto fornece uma infraestrutura automatizada e containerizada para instalar e rodar o servidor e-SUS APS PEC localmente. Ele utiliza **Docker**, **Docker Compose** e **Caddy** como proxy reverso para garantir comunicação HTTPS e isolamento do ambiente.

## ⚠️ Pré-requisito Importante: O Instalador do e-SUS

**O arquivo `.jar` do instalador do e-SUS NÃO está incluído neste repositório.**

Devido ao tamanho e questões de versionamento, você deve baixar o instalador oficial e colocá-lo na **raiz** deste projeto antes de executar qualquer script.

1. Baixe o instalador do e-SUS PEC (ex: `eSUS-AB-PEC-5.4.38-Linux64.jar`).
   https://sisaps.saude.gov.br/sistemas/esusaps/blog/versao-5-4-8/
   
2. Mova o arquivo para a raiz do projeto (mesmo nível do arquivo `docker-compose.yml`).
3. Certifique-se de que o nome do arquivo coincida com o definido na variável `INSTALADOR_NAME` no seu arquivo `.env`.

## Estrutura do Projeto

* `setup.sh`: Script principal que orquestra a criação de diretórios, geração de certificados SSL locais, build da imagem e execução do instalador interativo.
* `docker-compose.yml`: Define os serviços (`esus` e `caddy`), mapeamento de portas, redes e persistência de dados (volumes).
* `Dockerfile`: Configura a imagem base, instala dependências e prepara o ambiente para o e-SUS.
* `Caddyfile` (dentro da pasta `caddy/`): Configura o proxy reverso para garantir comunicação HTTPS via domínio local.

## Como Iniciar

1. **Clone o repositório:**
   ```bash
   git clone <url-do-seu-repositorio>
   cd <nome-da-pasta>
   ```

    Adicione o Instalador:

        Coloque o .jar baixado na raiz do projeto.

    Configure o Ambiente:

        Crie um arquivo .env na raiz do projeto contendo:
        Snippet de código

        INSTALADOR_NAME=eSUS-AB-PEC-5.4.38-Linux64
        ESUS_PORT=8083

    Execute o Setup:

        Dê permissão de execução: chmod +x setup.sh

        Rode o instalador: ./setup.sh

    Acompanhe a Instalação:

        O script abrirá o console interativo do instalador no seu terminal. Siga os passos na tela.

Persistência de Dados

O banco de dados é salvo na pasta ./data local, mapeada via volume. Isso garante que os dados não sejam perdidos ao reiniciar ou destruir o container.
