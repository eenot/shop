---
author: Thomas Weiser <elmdev@thomasweiser.de>
---

# Firebase Layout

## Schema

- shop
    - name: _String_
    - ...
- customers
    - _uid_
        - email: _String_
        - paymentData
            - id: _String_
            - object: _String_,
            - brand: _String_,
            - last4: _String_,
        - purchases
            - _slug_
                - _key_: _String_
- issues
    - _slug_
        - title: _String_
        - cover: _RelativeURL_
        - teaser: _HtmlString_
        - price: _Number_
- content
    - _slug_
        - _key_
            - body: _HtmlString_
- purchases
    - _uid_
        - _stripeChargeId_
            - issue: _Slug_
            - created: _Number_
            - amount: _Number_
            - receipt_email: _String_
            - currency: _String_

## Permissions

See [`fb-rules.json`](fb-rules.json)

- `/shop`  
  readable to anyone
- `/customers/$uid`  
  readable and writable for user `$uid` logged in
- `/issues`  
  readable to anyone
- `/content/$slug/$key`  
  readable if `$key == /customers/$uid/purchases/$slug`
- `/purchases/$uid`  
  writable for user `$uid`

## Notes

- The branch `/purchases` is for logging only. It is not readable by the user and it is not needed for normal operations.
- Stripe API <https://stripe.com/docs/api#charge_object>.
