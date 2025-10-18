# Simpleshare — HTTP Code Share em Bash

Simpleshare é um experimento/desafio pessoal: criar um servidor HTTP funcional usando apenas Bash puro (sem Python, Node, Go, etc), com autenticação, sessão, e frontend dinâmico, rodando via xinetd. O objetivo foi priorizar simplicidade e portabilidade, mesmo que algumas práticas não sejam ideais para produção.

## Estrutura de Pastas e Arquivos

```
simpleshare/
├── simpleshare.sh         # Instalador V1 (modo SIMPLE)
├── simplesharev2.sh       # Instalador V2 (detecta ambiente, instala modo SIMPLE)
├── simpleshare.html       # Frontend HTML com PetiteVue
├── simpleshare_server.sh  # Script gerado pelo instalador, servidor HTTP Bash
├── simpleshare.code       # Código compartilhado (gerado em runtime)
├── simpleshare.sessions   # Sessões de autenticação (gerado em runtime)
```

## Avisos e Ressalvas
- **Não recomendado para produção!** Este projeto é um experimento, feito para aprender e testar os limites do Bash.
- **Boas práticas sacrificadas:** O código prioriza simplicidade e legibilidade, não robustez, segurança ou escalabilidade.
- **Desafio pessoal:** O backend é 100% Bash, sem frameworks, usando xinetd para escutar a porta.
- **Dependências mínimas:** Precisa apenas de Bash, xinetd, e Python3 (para parsing JSON).

## Como instalar e rodar
1. Clone o repositório:
   ```sh
   git clone <repo-url>
   cd simpleshare
   ```
2. Execute o instalador:
   ```sh
   sudo bash simpleshare.sh
   # ou
   sudo bash simplesharev2.sh
   ```
3. Acesse o backend:
   ```sh
   curl http://localhost:8081
   ```
4. Configure o proxy reverso (nginx):
   ```
   proxy_pass http://localhost:8081;
   proxy_set_header X-Real-IP $remote_addr;
   ```

## Pré-requisitos
- Linux com Bash
- xinetd instalado (`sudo apt install xinetd`)
- Python3 instalado
- Permissão de root/sudo para instalar e configurar serviços

## Como funciona
- O instalador gera o servidor Bash (`simpleshare_server.sh`) e configura xinetd para escutar na porta 8081.
- O frontend HTML é lido dinamicamente do arquivo `simpleshare.html`.
- Sessões são gerenciadas por arquivo, com autenticação via senha.
- O código compartilhado é salvo em `simpleshare.code`.

## Observações
- O projeto foi feito para ser simples e didático, não para ser seguro ou escalável.
- O uso de Bash para HTTP é propositalmente limitado, mas divertido para aprender sobre parsing, sockets e manipulação de arquivos.
