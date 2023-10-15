# Configs for vpsAdmin-api used by vpsFree.cz

## `dataset_plans.rb`

A set of dataset plans available for user or admins. Plans are used to schedule
snapshots and transfers to a backup server.

## `dataset_properties.rb`

A set of dataset properties that vpsAdmin manages. Adding and removing
properties hass to come with a database migration to add/delete necessary
records to model DatasetProperty.

## `hooks.rb`
Use hooks fired by vpsAdmin-api.

 - DatasetInPool:create - create a backup dataset, add dataset plans in production
 - User:create - create a NAS dataset

