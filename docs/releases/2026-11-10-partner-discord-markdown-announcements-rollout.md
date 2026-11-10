# Rollout — anúncio Markdown dos parceiros no Discord (V20261110_001)

## Pré-flight
- Confirmar backup recente do MariaDB e que o schema selecionado é o de produção.
- Verificar que `V20261109_006` (publicações Discord) já foi aplicado.
- Verificar que `V20261110_001` ainda não está registrado pelo Flyway.
- Conferir cardinalidade e IDs sem modificar dados:

```sql
SELECT DATABASE() AS schema_ativo, VERSION() AS mariadb_version;
SELECT COUNT(*) AS publicacoes_atuais FROM partner_discord_publications;
SELECT COUNT(*) AS colunas_novas
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'partner_discord_publications'
  AND column_name IN (
    'announcement_markdown', 'announcement_links_mode',
    'announcement_public_contact', 'announcement_part_message_ids'
  );
```

Esperado antes da migration: `colunas_novas=0` (interromper se parcial). Rodar **o arquivo versionado pelo Flyway** no Database, não criar DDL na API/Coddy.

## Pós-flight
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'partner_discord_publications'
  AND column_name IN (
    'announcement_markdown', 'announcement_links_mode',
    'announcement_public_contact', 'announcement_part_message_ids'
  )
ORDER BY column_name;

SELECT
  COUNT(*) AS registros,
  SUM(announcement_links_mode = 'INLINE_ONLY') AS padrao_links_manuais,
  SUM(announcement_part_message_ids = '[]') AS sem_continuacoes,
  SUM(announcement_markdown IS NOT NULL) AS anuncios_personalizados
FROM partner_discord_publications;
```

Esperado: quatro colunas; registros preservados; todos os registros preexistentes com `INLINE_ONLY`, `[]` e Markdown nulo.

## Ordem
1. Database (Flyway migration e pós-flight confirmados).
2. Coddy (runtime suporta formato Markdown, preserva recursos e IDs legados).
3. API (contratos e atualização de revisões).
4. Front (editor e ações independentes de salvar e sincronizar).
5. Canário: salvar anúncio da **República Indie**, sem efeito externo; clicar **Publicar/atualizar** apenas nessa parceria; comparar thread, primeiro ID, partes extras, links, contato e nenhuma menção automática. Repetir uma sincronização inalterada e conferir que não duplicou mensagens.
6. NextFUR: testar texto longo, emojis personalizados e links manuais; editar um trecho intermediário, confirmar IDs preservados. Só então habilitar sincronização em lote.

## Segurança/rollback
- Migration aditiva: não converte nem apaga mensagens por conta própria.
- Se falhar o canário, interromper o lote; conservar os IDs e o banco. Corrigir Código/ACL antes de repetir.
- As mensagens de anúncio convertidas deixam de usar footer de embed; **não tentar restaurar embeddings antigos por SQL**.
- A confirmação funcional depende do Discord real e das permissões do Coddy; CI não substitui homologação.
- Não executar DML nem merge/deploy de produção sem autorização explícita.
