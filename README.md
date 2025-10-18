# Simpleshare Bash HTTP Server

Simpleshare é um servidor HTTP minimalista escrito em Bash, ideal para compartilhamento rápido de código ou texto via navegador. Não depende de frameworks externos e pode ser executado em qualquer ambiente Linux com Bash, xinetd e Python3.

## Instalação

```bash
sudo ./simpleshare.sh
# ou
sudo ./simplesharev2.sh
```

## Funcionalidades
- Autenticação simples por senha
- Compartilhamento de código/texto via API ou interface web
- Sessão temporária por IP e User-Agent
- Backend standalone (porta 8081)
- Pronto para proxy reverso com nginx

## Arquivos principais
- `simpleshare.sh` — Instalador modo simples
- `simplesharev2.sh` — Instalador com auto-detecção
- `simpleshare.html` — Interface web

## Segurança
A senha padrão é "SuaSenha". Recomenda-se alterar para uma senha forte antes de uso público.

## Licença
MIT
