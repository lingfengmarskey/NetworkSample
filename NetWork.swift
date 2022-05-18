import Apollo
import ApolloWebSocket
import Foundation

/// xxx need to be changed with yours.
let hostValue = "xxx.appsync-api.ap-northeast-1.amazonaws.com"
let hostKey = "host"

let normalEndPoint = "https://xxx.appsync-api.ap-northeast-1.amazonaws.com/graphql"
let realtimeEndPoint = "wss://xxx.appsync-realtime-api.ap-northeast-1.amazonaws.com/graphql"

let authKey = "x-api-key"
/// yyy need to be changed with yours.
let authValue = "da2-yyy"

/**
    Appsync payload format
 {
     data:{
         query: string josnstring base64
         variables: object optional
     }
     extension: {
         authorization: object optional
     }
 }
 */
enum PayloadKey: String {
    case data
    case query
    case variables
    case extensions
    case authorization
}

class Network {
    static let shared = Network()
    
    private init() {
        let store = makeStore()
        let normalTransport = makeNormalTransport(store: store)
        let wsRequest = makeWebSocketEndpoinRequesttForAppsnc()
        let webSocketTransport = makeWebSocketTransport(wsRequest)
        let splitNetworkTransport = SplitNetworkTransport(uploadingNetworkTransport: normalTransport,
                                                          webSocketNetworkTransport: webSocketTransport)
        self.apollo = ApolloClient(networkTransport: splitNetworkTransport, store: store)

    }

    /// A web socket transport to use for subscriptions
    ///
    ///  This web socket will have to provide the connecting payload which
    ///  initializes the connection as an authorized channel.
    private func makeWebSocketTransport(_ wsRequest: URLRequest) -> WebSocketTransport {
        let webSocketClient = WebSocket(request: wsRequest, protocol: .graphql_ws)
        let requestBody = AppSyncRequestBodyCreator([authKey: authValue])
        let webSocketTransport = WebSocketTransport(websocket: webSocketClient,
                                                    requestBodyCreator: requestBody)
        return webSocketTransport
    }

    /// A endpoint request url that web socket conneting.
    ///
    /// header-parameter-format-based-on-appsync-api-authorization-mode
    /// https://docs.aws.amazon.com/appsync/latest/devguide/real-time-websocket-client.html#header-parameter-format-based-on-appsync-api-authorization-mode)
    private func makeWebSocketEndpoinRequesttForAppsnc() -> URLRequest {
        let authDict = [
            authKey: authValue,
            hostKey: hostValue,
        ]

        let headerData: Data = try! JSONSerialization.data(withJSONObject: authDict, options: JSONSerialization.WritingOptions.prettyPrinted)
        let headerBase64 = headerData.base64EncodedString()

        let payloadData = try! JSONSerialization.data(withJSONObject: [:], options: JSONSerialization.WritingOptions.prettyPrinted)
        let payloadBase64 = payloadData.base64EncodedString()

        let url = URL(string: realtimeEndPoint + "?header=\(headerBase64)&payload=\(payloadBase64)")!
        let request = URLRequest(url: url)
        return request
    }

    /// An HTTP transport to use for queries and mutations.
    private func makeNormalTransport(store: ApolloStore) -> RequestChainNetworkTransport {
        let url = URL(string: normalEndPoint)!
        let transport = RequestChainNetworkTransport(interceptorProvider: DefaultInterceptorProvider(store: store), endpointURL: url, additionalHeaders: [authKey: authValue])
        return transport
    }

    private(set) var apollo:ApolloClient!

    /// A common store to use for `normalTransport` and `client`.
    private func makeStore() -> ApolloStore  {
        let cache = InMemoryNormalizedCache()
        return ApolloStore(cache: cache)
    }
}

/// Communication message payload body creator
class AppSyncRequestBodyCreator: RequestBodyCreator {
    init(_ authorization: [String: String]) {
        self.authorization = authorization
    }

    private var authorization: [String: String]

    public func requestBody<Operation>(for operation: Operation,
                                       sendOperationIdentifiers _: Bool,
                                       sendQueryDocument _: Bool,
                                       autoPersistQuery: Bool) -> GraphQLMap where Operation: GraphQLOperation {
        var body: GraphQLMap = [:]

        var dataInfo: [String: Any] = [:]
        if let variables = operation.variables {
            dataInfo[PayloadKey.variables.rawValue] = variables
        }
        dataInfo[PayloadKey.query.rawValue] = operation.queryDocument

        // The data portion of the body needs to have the query and variables as well.
        guard let data = try? JSONSerialization.data(withJSONObject: dataInfo, options: .prettyPrinted) else {
            fatalError("Somehow the query and variables aren't valid JSON!")
        }
        let jsonString = String(data: data, encoding: .utf8)
        body[PayloadKey.data.rawValue] = jsonString

        if autoPersistQuery {
            guard let operationIdentifier = operation.operationIdentifier else {
                preconditionFailure("To enable `autoPersistQueries`, Apollo types must be generated with operationIdentifiers")
            }

            body[PayloadKey.extensions.rawValue] = [
                "persistedQuery": ["sha256Hash": operationIdentifier, "version": 1],
                PayloadKey.authorization.rawValue: [
                    authKey: authValue,
                    hostKey: hostValue,
                ],
            ]
        } else {
            body[PayloadKey.extensions.rawValue] = [
                PayloadKey.authorization.rawValue: [
                    authKey: authValue,
                    hostKey: hostValue,
                ],
            ]
        }

        return body
    }
}
