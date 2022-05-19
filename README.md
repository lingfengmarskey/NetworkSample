# AppSync With Apollo(iOS)

Recently I met a problem.
> 1. For building a GraphQL Application that has a server with AWS AppSync, and Apollo SDK as client tool.
> 2. Ream-time is requrement so I will use GraphQL Subscription. By some reason can not use the Amplify of AWS.
> 3. Integrate them in an iOS client and test them.

---

There are 3 steps mainly:

1. Build server api by AppSync console.
2. Build client program and integrate Apollo in it.
3. Generate code about GraphQL in client, and test functionality.


#### Step1 and Step2 can be completed smoothly if following the official docs. But most problems are in step 3.

1. If `codegen` failed, it may be there wrong in the schema.json file.
2. `Operation.graphql` files are required by default.
3. Subscription
    1. Its endPoint is a little different and `Query`, `mutation`.
    2. Server that implementd sub protocal of GraphQL over Websocket Protocol may be different.
        - `AppSync`'s server protocol is `graphql-ws`, so we need manually config that by Apollo SDK.
    3. Need customize a header in auth mode.
        - [Header parameter format based on AWS AppSync API authorization mode](https://docs.aws.amazon.com/appsync/latest/devguide/real-time-websocket-client.html#header-parameter-format-based-on-appsync-api-authorization-mode)
    4. Format of payload.
        - Format of payload in connection is different in `Apollo` SDK and `AppSync`,so we need fix that.
        - Appsync payload

            ```
            {
                "id": "subscriptionId",
                "type": "start",
                "payload":
                {
                    "data":
                    {
                        "query": "query stirng",
                        "variables": "variables"
                    },
                    "extensions":
                    {
                        "authorization":
                        {
                            "host": "host",
                            "x-api-key": "apikey"
                        }
                    }
                }
            }
            ```
        -  Apollo payload

            ```
            {
                "id": "subscriptionId",
                "type": "start",
                "payload":
                {
                    "variables": "variables",
                    "extensions": "extensions",
                    "operationName": "subscriptionName",
                    "query": "quey string"
                }
            }
            ```

Because of something above, I customized a simple network class as a sample. It just contains some simple and required things.

