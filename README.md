# e-SUS APS — Docker

Passo a passo para instalar e acessar o e-SUS APS rodando em container Docker.

## Pré-requisitos

- Linux com Docker e Docker Compose instalados
- Os arquivos deste projeto (Dockerfile, docker-compose.yml, entrypoint.sh, esus.service, run-installer.sh, setup.sh, configurar-acesso.sh)

> **Aviso:** Todos os comandos abaixo devem ser executados com privilégios de administrador (`sudo`).

---

## Passo 1 — Subir o container e instalar

Na pasta do projeto, primeiro dê permissão aos scripts e inicie o container forçando a reconstrução para garantir que os arquivos mais recentes (como o `esus.service`) sejam aplicados:

```bash
sudo chmod +x run-installer.sh configurar-acesso.sh
sudo docker-compose down -v
sudo docker-compose up -d --build
```

- `down -v` limpa qualquer resíduo de uma tentativa anterior.
- `--build` garante que a imagem seja reconstruída com os arquivos atuais.

Com o container rodando, inicie o instalador:

```bash
sudo docker exec -it esus_server /opt/run-installer.sh
```

O instalador roda de forma automática (a pergunta de confirmação S/N já é respondida sozinha), mas você acompanha tudo rolando na tela normalmente. Para acompanhar o progresso final, veja os logs:

```bash
sudo docker logs -f esus_server
```

Espere aparecer a linha:
`Pronto.`

Depois disso pode apertar `Ctrl+C` — o container continua rodando normalmente.

---

## Passo 2 — Configurar o acesso pelo nome (`esusserver.local`)

Para que o seu navegador reconheça o endereço do servidor local, rode o script:

```bash
sudo ./configurar-acesso.sh
```

Esse script adiciona a entrada `127.0.0.1 esusserver.local` no `/etc/hosts` da sua própria máquina. 

O certificado é autoassinado, então o navegador vai avisar "conexão não segura". Isso é esperado: clique em "Avançado" → "Continuar mesmo assim" (ou equivalente no seu navegador).

---

## Passo 3 — Acessar o sistema

Acesse no navegador:

https://esusserver.local:8443

---

## Passo 4 — Link da instalação (dentro do sistema)

Se o e-SUS pedir, dentro do sistema, para preencher o **link da instalação** (em telas como "Configurações da Instalação"), use a porta **443** (não a 8443):

https://esusserver.local:443

*(A porta 8443 é só o mapeamento externo para o seu host; internamente, dentro do container, o Tomcat do e-SUS escuta na 443 — é isso que ele valida sozinho).*

---

## Banco de dados (PostgreSQL)

O banco de dados do e-SUS fica exposto na porta **5433**, podendo ser acessado externamente por ferramentas como o DBeaver.

---

## Conferindo se está tudo certo

Se em algum momento quiser confirmar se a aplicação subiu corretamente no container sem depender do navegador ou DNS, você pode checar os logs novamente:

```bash
sudo docker logs -f esus_server
```
*(Deve aparecer a linha `Pronto.` no final da configuração automática)*

Ou testar a resposta do servidor diretamente via terminal:

```bash
sudo curl -vk https://127.0.0.1:8443/