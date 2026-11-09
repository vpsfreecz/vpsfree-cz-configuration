# vpsAdmin abuse notice operations

The [parser reference](https://github.com/vpsfreecz/vpsfree-cz-configuration/blob/master/configs/vpsadmin/api/abuse-notices.md)
owns provider matching, historical assignment, evidence disclosure and failure
semantics. Review it before reprocessing notices: a handled message can have
rejected entries, and `EXECUTE=yes` deletes fetched mail independently of parser
success. Dry runs leave mail and incident records unchanged.

## Verification

Run the parser suite from the repository root in the configuration development
shell:

```bash
nix develop -c bundle exec rake spec
```

## Recovery

Use the original RT ticket to investigate rejected entries. Before manually
reprocessing a report, inspect the incidents already created and select only
missing entries. There is no cross-message deduplication or automatic retry in
this parser. Database and notification failures can leave some records or
notifications already completed; check those effects before recovery.

## Deployment and rollback

The parser uses the existing vpsAdmin incident-array interface and needs no
schema migration or coordinated node update. Deploy it with the API's
configuration. Rolling back restores the previous parser behavior; it does not
remove incidents or retract notifications already sent.
