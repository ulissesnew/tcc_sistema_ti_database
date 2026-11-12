# Banco de dados — Sistema TI

Este ambiente inicia o banco existente em MySQL 8.0. O dump original, `sistema_ti(1).sql`, não é alterado. A inicialização inclui dados e testes de fumaça identificados como `TCC_TEST_*`; portanto, este Compose é destinado ao ambiente local de desenvolvimento/teste.

## Primeiro uso

1. Crie o arquivo local de credenciais e ajuste as senhas:

   ```bash
   cp .env.example .env
   ```

2. Inicie o banco:

   ```bash
   docker compose up -d
   ```

3. Confira o estado do serviço:

   ```bash
   docker compose ps
   ```

O MySQL fica acessível somente na máquina local, em `127.0.0.1:${MYSQL_PORT}` (porta `3306` por padrão).

## Interface web (Adminer)

Após iniciar o Compose, acesse [http://127.0.0.1:8080](http://127.0.0.1:8080) no navegador. A porta pode ser alterada com `ADMINER_PORT` em `.env`.

Na tela de login, use:

- Sistema: `MySQL`
- Servidor: `mysql`
- Usuário: o valor de `MYSQL_USER` em `.env`
- Senha: o valor de `MYSQL_PASSWORD` em `.env`
- Base de dados: `sistema_ti`

O Adminer também está limitado a `127.0.0.1`; ele não fica disponível para outros dispositivos da rede.

## Parar sem perder dados

```bash
docker compose stop
```

Para iniciar novamente:

```bash
docker compose start
```

Não use `docker compose down -v` a menos que queira apagar deliberadamente os dados persistidos.

## Conectar com o cliente MySQL

Com o contêiner em execução:

```bash
docker compose exec mysql sh -c 'mysql -u"$MYSQL_USER" -p "$MYSQL_DATABASE"'
```

O comando pedirá a senha definida em `.env`. Alternativamente, entre como root com `-uroot` e a senha `MYSQL_ROOT_PASSWORD`.

## Inspecionar tabelas e logs

```bash
docker compose exec mysql sh -c 'mysql -u"$MYSQL_USER" -p -e "SHOW TABLES" "$MYSQL_DATABASE"'
docker compose logs mysql
```

## Como a inicialização funciona

Na primeira criação do volume nomeado `mysql_data`, a imagem oficial do MySQL cria o banco definido em `MYSQL_DATABASE` e executa os arquivos SQL em `/docker-entrypoint-initdb.d`, em ordem alfabética:

1. `01-sistema_ti.sql` — importa o dump original.
2. `02-tcc-step-1-update-existing-tables.sql` — aplica automaticamente `TCC_Step_1_Update_Existing_Tables.sql`.
3. `03-tcc-step-1-seed-and-automated-tests.sql` — insere os dados de teste `TCC_TEST_*` e executa os testes de fumaça de `TCC_Step_1_Seed_and_Automated_Tests.sql`.
4. `04-tcc-step-2-core-tables.sql` — cria as tabelas centrais `manutencoes` e `descartes` a partir de `TCC_Step_2_Core_Tables.sql`.

Os quatro arquivos são montados como somente leitura. O resultado `PASS`/`FAIL` dos testes é gravado nos logs de inicialização do MySQL e pode ser consultado com:

```bash
docker compose logs mysql
```

Esses scripts são executados somente quando o diretório de dados está vazio. Nas reinicializações, o volume preserva o banco e o dump não é reaplicado, evitando substituir dados existentes.

## Aplicar alterações em um banco já criado

Os scripts de inicialização não são repetidos automaticamente em um volume já existente. Antes de aplicar qualquer alteração, faça backup e revise as consultas de pré-verificação presentes no script.

Para a atualização do Step 1, que contém comandos `ALTER TABLE` não idempotentes, execute uma única vez:

```bash
docker compose exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < TCC_Step_1_Update_Existing_Tables.sql
```

Depois, se ainda não tiver sido executado, aplique os dados e testes do Step 1:

```bash
docker compose exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < TCC_Step_1_Seed_and_Automated_Tests.sql
```

Por fim, aplique o Step 2 para criar as tabelas `manutencoes` e `descartes`:

```bash
docker compose exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < TCC_Step_2_Core_Tables.sql
```

O Step 2 usa `CREATE TABLE IF NOT EXISTS`, mas essa cláusula não valida o esquema de uma tabela preexistente. Confirme a criação com:

```bash
docker compose exec mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW TABLES LIKE '\''manutencoes'\''; SHOW TABLES LIKE '\''descartes'\'';" "$MYSQL_DATABASE"'
```

Para recriar **somente um ambiente local descartável** e deixar o Compose aplicar dump e atualização desde o início, remova o volume e suba os serviços novamente:

```bash
docker compose down -v
docker compose up -d
```
