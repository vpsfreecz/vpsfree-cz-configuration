# Authentication logos

These transparent PNGs are local copies of the vpsFree.cz logos from
[vpsf-status](https://github.com/vpsfreecz/vpsf-status/tree/8e17ccb9728bed308bbe7d67126eb84dfdf8a81c/public).
They are copied unchanged; authentication has no build or runtime dependency on
the status service.

| Local file | Source path | Dimensions | SHA256 |
| --- | --- | --- | --- |
| `vpsfree.png` | `public/vpsfree.png` | 540 × 185 | `836faaf1594fbc750c5903f0b335f6556fae6fb93da77cfd124f1d6b6c02d740` |
| `vpsfree-dark.png` | `public/vpsfree-dark.png` | 173 × 50 | `c843b27b0695fbcffc0d341a7a23194e025bb6ce8537a4fd23092fc624674e5a` |

The dark asset is the white/orange logo for dark backgrounds. Its Git blob
`41a78b8dc4f2ee76d847453b7d2da85ae4f037f6` also matches
[`web:obrazky/vpsFree-bile.png`](https://github.com/vpsfreecz/web/blob/7fec3e3ccc5a1aa41bad7f06f83d01fa6cd15fe9/obrazky/vpsFree-bile.png).
Preserve each image's aspect ratio when displaying it; their dimensions differ.

The site passes these local files to the vpsAdmin Nix logo options. The module
copies them into both API hosts' immutable store closures, and the API serves
the matching scheme through its built-in auth logo routes. See the
[API configuration](../api/README.md#authentication-branding) for the declarative
options and [OAuth operations](../../../docs/operations/vpsadmin-documentation-oauth.md#appearance-and-branding)
for activation and rollback ordering.
