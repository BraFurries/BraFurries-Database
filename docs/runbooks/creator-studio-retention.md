# Creator Studio — retenção de commissions (decisão 17/11/2026)

## Regra de negócio

- **12 meses de calendário após a última conclusão** (não após pedido nem cadastro).
- O relógio usa `completed_at` em UTC; `requested_on` é data civil e **não** inicia retenção.
- Uma commission só é elegível quando `status='COMPLETED'` e `completed_at IS NOT NULL`.
- Reabrir remove `completed_at`; concluir novamente fixa nova data de início.
- Commissions QUEUED, IN_PROGRESS, WAITING e PAUSED nunca participam da limpeza por idade.
- Etapas, anotações, referências e eventos de revisão da commission excluída são apagados **na mesma transação**, nessa ordem: `creator_studio_activity`, `creator_studio_reference_links`, `creator_studio_commission_steps`, `creator_studio_commissions`.
- Tipos de arte, definições compartilhadas, modelos, assinatura Pro vitalícia e auditoria administrativa **não** são apagados nesta rotina.
- A retenção aplica-se mesmo após revogação de assinatura, preservando antes da expiração o direito de exportar os dados pelo usuário autenticado.

## Avisos e direito de exportação

- API oferece a visão de commissions encerradas cujo prazo termina nos próximos **30 dias**, com destaque reforçado quando faltam **7 dias**, inclusive marcando registros vencidos.
- Os avisos **desta PR** são exibidos dentro do Studio; **não há envio por e-mail garantido ainda**.
- API permite exportação JSON de catálogo, commissions, etapas, referências e histórico para o usuário autenticado, **inclusive após revogação de Pro**. Links são exportados como URLs; arquivos hospedados externamente não são copiados.
- Antes de ativar qualquer exclusão real, disponibilizar e **validar entrega persistente dos avisos** de 30/7 dias (por exemplo e-mail transacional com retry e deduplicação), além de publicar a política de privacidade. Nunca tratar visualização eventual de página como garantia de notificação.
- Deverão existir processos de retenção excepcional por obrigação legal, litígio ou solicitação válida, antes da ativação geral da limpeza.

## Avisos automáticos e retenções excepcionais (preparação da fase seguinte)

- Migration `V20261117_004__creator_studio_retention_notices_holds.sql` cria três tabelas: lembretes idempotentes, retenções excepcionais e auditoria mínima.
- `creator_studio_retention_notices`: 30 (`D30`) e 7 (`D7`) dias antes do aniversário de **um ano após a última conclusão**. Chave única por **artista, commission, completed_at e tipo de aviso**; ao reabrir e concluir novamente, o novo `completed_at` exige novas notificações.
- A rotina envia e-mails sem nomes de clientes nem conteúdo de commissions, apenas link do Studio e instrução de exportação. Somente e-mails da conta **verificados localmente** e de usuários não consolidados são elegíveis. Contas OAuth sem comprovação local de e-mail exigem mecanismo de confirmação antes de envio.
- `CREATOR_STUDIO_RETENTION_NOTICES_ENABLED=false` **por padrão**. Habilitar somente após SMTP configurado, verificação de remetente e testes com destinatários controlados.
- Estados: `PENDING` → `SENDING` → `SENT` (aceito pelo servidor SMTP) ou `UNKNOWN`. `UNKNOWN` e `SENDING` **nunca** são reprocessados automaticamente: um erro/time-out pode ter ocorrido após o SMTP aceitar a mensagem. Verificar manualmente a trilha antes de qualquer reenvio.
- **SMTP aceito não equivale a entrega na caixa de entrada.** Para prometer comprovação de entrega, integrar webhooks de provedor transacional, bounces e tracking idempotente. O envio desta etapa NÃO constitui prova de recebimento.
- Registros antigos cujo aviso D30 não pôde ser enviado em tempo, usuário sem e-mail verificado ou e-mail ambíguo permanecem **bloqueados para exclusão**; revisar individualmente e comunicar por canal adequado.
- Mesmo com as duas flags de limpeza ligadas, a API só pode remover uma commission se a versão **atual** de `completed_at` tiver ambos os avisos `D30` e `D7` com `status='SENT'` e `sent_at IS NOT NULL`, e não houver `hold` ativo.
- `creator_studio_retention_holds`: bloqueio ativo por commission/artista, com categoria e justificativa obrigatória; apenas proprietário da plataforma pode colocar ou liberar, via API e painel **Administração → Piloto Creators**. O lock da comissão serializa a liberação com o worker de exclusão.
- `creator_studio_retention_hold_events`: auditoria mínima de `PLACED/RELEASED`, categoria, IDs internos e ator; não armazena notas privadas nem cliente. O evento não depende de FK com a commission para sobreviver à limpeza.
- Reabrir a commission cancela elegibilidade imediatamente; notificações antigas permanecem vinculadas ao `completed_at` anterior e **não** legitimam exclusão de nova conclusão.
- A exclusão continua exigindo `CREATOR_STUDIO_RETENTION_PURGE_ENABLED=true` **E** `CREATOR_STUDIO_RETENTION_NOTICES_READY=true`, ambas false por padrão. Habilitar apenas depois de auditar a política, opt-in operacional e prova de entrega.

### Consulta de auditoria em ambiente controlado

```sql
SELECT notice_kind,status,attempts,claimed_at,sent_at,last_error_code
FROM creator_studio_retention_notices
WHERE owner_user_id=? AND commission_id=?
ORDER BY completed_at,notice_kind;
```

Esta consulta é **somente leitura** e deve ser feita em ambiente autorizado, sem exibir e-mails ou detalhes dos clientes nos logs públicos.

## Segurança técnica

- `V20261117_003__creator_studio_retention_index.sql`: adiciona índice em `(status,completed_at,id)` à tabela já existente. **Não contém DELETE nem backfill.**
- Job/API operam com `owner_user_id` derivado da conta ou da commission selecionada, nunca enviado pelo cliente.
- Exclusão seleciona candidatos em lote de **até 50 por execução diária**, mas somente quando `app.creator-studio.retention.purge-enabled=true` **E** `app.creator-studio.retention.notification-delivery-ready=true`.
- **Ambos ficam FALSE durante o piloto**. Só ativar quando notificação e exportação estiverem validadas, junto com aprovação explícita de rollout.
- Cada exclusão é uma transação com `SELECT ... FOR UPDATE` que revalida status e prazo e só depois remove as tabelas filhas; erro reverte a transação.
- Para permitir uso do índice e manter semântica exata de ano de calendário (inclusive 29/02), queries aplicam um filtro conservador e depois `DATE_ADD(completed_at,INTERVAL 1 YEAR)`.
- Logs somente com contagem de registros removidos; sem imprimir nomes, clientes ou conteúdo de pedidos.

## Checklist de rollout (não concluído)

1. Validar Flyway/MariaDB descartável e índice, sem aplicar migration produtiva.
2. Testar exportação JSON com nomes internacionais, URLs, notas, datas e **muitos trabalhos**; testar acesso com assinatura revogada.
3. Testar reabertura de pedido e corrida entre atualização e limpeza com concorrência real MariaDB.
4. Implementar e validar canal de notificação 30/7 dias com prova de entrega, idempotência e reenvio.
5. Definir exceções legais/retenção sob disputa e publicar política ao usuário.
6. Validar conjunto empilhado Database #69/#70 e API/Front correspondente em staging.
7. Habilitar primeiro **dry run/report**, sem DELETE, com métricas comparadas ao esperado; só depois aprovar ativação real.

**Não ativar a exclusão automática em produção durante o piloto.**
