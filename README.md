# xepa-server

Infra do Supabase do Xepa: schema SQL, políticas de RLS e (futuramente) Edge Functions. Não é um servidor HTTP próprio — o Xepa não tem backend REST/GraphQL; o front (`xepa-system`) fala direto com o Supabase.

Ver `../xepa-agents/backend-agent-rules-xepa.md` para as regras de modelagem/RLS e `../pipeline/Xepa_Pipeline_do_Projeto.md` para o modelo de dados completo.

## Estrutura

```
supabase/
└── migrations/
    ├── 0001_init.sql          # profiles, invites, RLS, trigger de aprovação/cargo
    ├── 0002_signals.sql       # signals, signal_confirmations
    ├── 0003_meals.sql         # meals, meal_confirmations
    ├── 0004_leftovers.sql     # leftovers (reserva condicional)
    ├── 0005_sos.sql           # sos_requests (resolução condicional)
    ├── 0006_splits.sql        # splits, split_participants, RPC create_split
    ├── 0007_pearls.sql        # pearls, pearl_reactions
    └── 0008_food_options.sql  # food_options
```

## Aplicando as migrations

Com o [Supabase CLI](https://supabase.com/docs/guides/cli) configurado e linkado ao projeto:

```bash
supabase db push
```
