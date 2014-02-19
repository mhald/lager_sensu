Enables lager to publish live logging data to popcorn.

### Configuration

In the app.config add a lager_sensu entry to the lager config.

Example:

```
{lager, [
         {handlers, [
            {lager_console_backend, none},
            {lager_file_backend,
             [
              {"log/error.log", error, 104857600, "$D0", 5},
             ]},
             {lager_sensu, [
                 {level,            critical},
                 {sesnu_host,     "hostname"},
                 {sesnu_port,     9125}
             ]}
  ]}
 ]},
```
