# xepa-server

Infra do Supabase do Xepa: schema SQL, políticas de RLS e (futuramente) Edge Functions. Não é um servidor HTTP próprio — o Xepa não tem backend REST/GraphQL; o front (`xepa-system`) fala direto com o Supabase.

Ver `../xepa-agents/backend-agent-rules-xepa.md` para as regras de modelagem/RLS e `../pipeline/Xepa_Pipeline_do_Projeto.md` para o modelo de dados completo.

## Estrutura

```
supabase/
└── migrations/
    └── 0001_init.sql   # profiles, invites, RLS, trigger de aprovação/cargo
```

## Aplicando as migrations

Com o [Supabase CLI](https://supabase.com/docs/guides/cli) configurado e linkado ao projeto:

```bash
supabase db push
```
