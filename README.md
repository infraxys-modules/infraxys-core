# Infraxys core module


This module is used by Infraxys to setup the environment when executing actions.  


## Bash functions

### load_git_config_variable

This function configures the environment for Git. 


#### Arguments:
git_config_variable: required. The name if the Infraxys-variable that holds JSON like below. Type should be "GIT-CONFIG"
set_global_config: optional, default 'false'. Specify 'true' if additional global config from the JSON variable should be set.

Example GIT-CONFIG variable contents:
```json
{
  "hostname": "github.com",
  "token": "<REDACTED>",
  "config": [
    {
      "name": "user.name",
      "value": "my-github-username"
    },
    {
      "name": "user.email",
      "value": "my-email@for-git.example"
    },
    {
      "name": "push.default",
      "value": "simple"
    }
  ]
}
```
