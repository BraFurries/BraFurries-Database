# Parceiros no Discord — contrato e rollout

**Estado:** infraestrutura de schema proposta; nenhuma publicação em Discord ou aplicação em produção foi feita.

## Autoridades

- Database: guarda configuração por Community (instância oficial), referências a recursos Discord e revisões.
- API: valida a Community oficial, autorização PARTNERS_MANAGE, identidade comprovada do representante, status ativo, conteúdo, links e configuração de canais.
- Coddy: cria/atualiza recursos dentro da guild autorizada, sem decidir quem é parceiro. Nunca faz DDL.
- Front: UI de configuração e indicação de sync; nenhuma permissão apenas visual.

## Limitação técnica do Discord

Threads públicas herdam permissões do canal pai. Não existe overwrite por thread que permita a cada representante escrever apenas na sua. A proposta é **vitrine de threads somente leitura**, com postagens enviadas por um endpoint de representante autenticado na API e publicadas pelo Coddy. Canais individuais aceitam **overwrites de membro** para escrita direta. Administradores/moderadores do Discord mantêm poderes inerentes à sua função.

## Contrato para publicações

- Só parceiros ativos; representante de publicação precisa de vínculo `user_discord.discord_user_id` quando o bot precisa atribuir direitos nativos no canal privado.
- Lista de links vinda do cadastro `partner_external_links`, validada pela API e sanitizada no Coddy para desabilitar menções.
- `partner_discord_config` contém exclusivamente o guild oficial associado à Community permitida.
- `partner_discord_publications` guarda o desejo do canal exclusivo, escolha opcional de canal preexistente e IDs aplicados pelo Coddy. `desired_revision` / `applied_revision` tornam drift visível.
- Configuração de categoria/canal existente exige verificação de tipo, guild, permissões e confirmação da adoção; não mudar canais alheios silenciosamente.
- Desativação/exclusão tem preflight e limpeza coordenada; RESTRICT impede perda acidental do mapeamento de publicação.
- Criação de recursos deve ser idempotente e reconciliável por ID e marcador estável do parceiro.
- Mudanças administrativas exigem auditoria (ator, recurso, antes/depois).

## Execução

1. Revisar e integrar migration do Database, sem executá-la automaticamente.
2. Implementar Coddy read-only posting, reconciliação, permissões nativas de canais e testes isolados.
3. Implementar API CRUD/configuração e autenticação de publicação, com testes de autorização/isolamento; deploy só após migration.
4. Integrar a aba Discord no Front e editar opção de canal exclusivo por parceiro; testar build e fluxo de alteração.
5. Revisar diffs, checks, dados legados, canal escolhido, rollback e preflight. Mergers/deploys apenas mediante autorização.

## Validação manual sem acesso a produção

```bash
python validation/scripts/validate_migrations.py --allow-official
python validation/scripts/partner_discord_smoke_test.py
```

Nenhuma migration limpa dados existentes. Para rollback em produção, **não** fazer DROP automático de tabelas nem perder IDs de recursos Discord: desativar integração e reconciliar antes.
