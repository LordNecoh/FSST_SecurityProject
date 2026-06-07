# HTTP Data Leak — Proxy and Malicious Server

This project implements the network-security assignment scenario. It contains a malicious HTTP server that receives data through custom data-leak techniques, and a proxy/bridge that forwards client requests to the server while blocking the leak when the traffic passes through the proxy.

The scenario is run with Docker Compose and starts two HTTP services:

- the proxy listens on `localhost:8000`;
- the malicious server listens on `localhost:8001`.

The direct server port is used to show that the leak techniques work. The proxy port is used to show that the same techniques are neutralized when the defensive bridge is used.

---

## 1. Architecture

```text
                    Protected path

[ Client / data leaker ]
          |
          | HTTP on localhost:8000
          v
[ Proxy / bridge container ]
          |
          | HTTP to server:8001
          v
[ Malicious server container ]


                    Direct test path

[ Client / data leaker ] ---> HTTP on localhost:8001 ---> [ Malicious server ]
```

### Components

The project has two main components.

The `proxy` service listens on port `8000` that behaves like a transparent bridge: it receives client requests, forwards them to the malicious server, receives the server response, and sends it back to the client. For configured leak entrypoints, it sanitizes only the malicious `PUT /<entrypoint>` requests.

The `server` service listens on port `8001`. It is the malicious HTTP service that registers dynamic entrypoints, receives data through the implemented covert channels, reconstructs the leaked value, stores it in memory, and returns it through `GET /<entrypoint>`.

The proxy is intentionally separated from the malicious server. This models the case in which a network administrator cannot directly modify the service but can place a defensive bridge in front of it.

---

## 2. Implemented leak techniques

The implementation supports multiple independent leak activities at the same time and each activity is identified by its own dynamic entrypoint.

### 2.1 Dedicated header — `dedicated_header`

The client transfers data through the custom HTTP header `X-dataleak`.

Example direct leak request:

```http
PUT /sampleleak HTTP/1.1
Host: localhost:8001
X-dataleak: Y2lhbw==
```

`Y2lhbw==` is the Base64 representation of `ciao`.

Server behavior:

- the server reads the value of `X-dataleak`;
- the value is stored as the leaked value for that entrypoint;
- if the same entrypoint receives another dedicated-header leak, the newest value replaces the previous one.

Proxy defense:

- the proxy removes the leak-carrying header before forwarding the request;
- as a result, the malicious server receives no useful data for that leak.

### 2.2 Headers order — `headers_order`

The client transfers one bit per HTTP request by changing the relative order of two headers.

The implemented test convention is:

```text
Header-A before Header-B  -> bit 0
Header-B before Header-A  -> bit 1
```

Eight consecutive bits form one ASCII character and a sequence of eight zero bits, `00000000`, terminates the current string.

For usage of the assignment, the logical payload should be Base64-encoded text. For example like we report before, the string `ciao` should be sent as the ASCII characters of `Y2lhbw==`, followed by the `00000000` terminator.

Server behavior:

- each valid request contributes one bit to the entrypoint bit buffer;
- every group of 8 bits is decoded as one ASCII character;
- `00000000` terminates the current string;
- data sent after a terminator starts a new value and replaces the previous reconstructed value.

Proxy defense:

- the proxy changes the header sequence before forwarding the request;
- this destroys the ordering-based bit encoding;
- the server therefore reconstructs either no data or incorrect data, so the leak is neutralized.

---

## 3. API reference

The same API is available through the proxy on port `8000` and directly on the malicious server on port `8001`.

Use port `8000` to test the protected scenario. Use port `8001` only to show that the malicious server would work if the proxy were bypassed.

Important: in the protected scenario, send `POST /setup` through the proxy on port `8000`. The proxy records the entrypoint during setup; if setup is sent only to port `8001`, the malicious server knows the entrypoint but the proxy does not know that the corresponding `PUT` requests must be sanitized.

### 3.1 `POST /setup`

Registers a dynamic leak entrypoint.

This request is forwarded by the proxy without sanitization.

```bash
curl -X POST http://localhost:8000/setup \
  -H "Content-Type: application/json" \
  -d '{"entrypoint": "sampleleak", "type": "dedicatedheader"}'
```

Request body:

| Field | Type | Description |
| --- | --- | --- |
| `entrypoint` | string | URI path to use for the leak. Both `sampleleak` and `/sampleleak` are accepted. |
| `type` | string | Leak technique. Allowed values: `dedicatedheader`, `headersorder`. |

Expected result:

- `200 OK` if the setup succeeds;
- `400 Bad Request` if the leak type is not supported by the malicious server.

### 3.2 `PUT /<entrypoint>`

Sends data to the configured leak entrypoint.

This is the only request type sanitized by the proxy.

Dedicated-header example through the proxy:

```bash
curl -X PUT http://localhost:8000/sampleleak \
  -H "X-dataleak: Y2lhbw=="
```

Dedicated-header example bypassing the proxy:

```bash
curl -X PUT http://localhost:8001/sampleleak \
  -H "X-dataleak: Y2lhbw=="
```

Expected result:

- through `8000`, the proxy sanitizes the request and the leak should fail;
- through `8001`, the malicious server receives the leak directly and stores it.

### 3.3 `GET /<entrypoint>`

Retrieves the value reconstructed by the malicious server.

```bash
curl -X GET http://localhost:8000/sampleleak
```

Expected result:

- `200 OK` with the reconstructed value if the entrypoint exists;
- `404 Not Found` if the entrypoint has not been configured.

### 3.4 `DELETE /clear`

Clears all in-memory server state: configured entrypoints, leaked values, and partial bit buffers.

This endpoint is intended for repeatable tests and demonstrations.

```bash
curl -X DELETE http://localhost:8001/clear
```

---

## 4. Requirements

All the following tools need to be installed before running the project:

- Docker
- Docker Compose plugin (`docker compose`)
- `curl`
- a Bash-compatible shell

No HTTPS configuration is required in fact the assignment tests just the HTTP endpoints.

The services use in-memory state, by restarting the containers or calling `DELETE /clear` removes configured entrypoints, leaked values, and partial bit buffers.

---

## 5. Run from scratch

### 5.1 Extract the submission archive

```bash
unzip progetto_dataleak.zip
cd progetto_dataleak
```

If the archive has a different name, replace `progetto_dataleak.zip` with the actual file name.

### 5.2 Build and start the containers

```bash
docker compose up --build -d
```

This command builds both services and starts them in the background.

### 5.3 Check that both services are running

```bash
docker compose ps
```

The expected exposed ports are:

```text
0.0.0.0:8000->8000/tcp    proxy
0.0.0.0:8001->8001/tcp    server
```

### 5.4 View logs during the demonstration

```bash
docker compose logs -f
```

If you encounter issues with Docker Compose, we recommend using the `logs` flag to view the system logs during the Compose phase

### 5.5 Stop the environment

```bash
docker compose down
```

---

## 6. Automated tests

Make the test scripts executable:

```bash
chmod +x test_complete.sh test_tec1.sh test_tec2.sh test_server.sh
```

### 6.1 Complete protected test through the proxy

```bash
./test_complete.sh 8000 on
```

Expected behavior:

- `dedicatedheader` does not leak the original value;
- `headersorder` does not reconstruct the original string;
- the script reports that the protected behavior is correct.

### 6.2 Direct malicious-server test

```bash
./test_complete.sh 8001 on
```

Expected behavior:

- `dedicatedheader` successfully stores and returns `dGVjMQ==`;
- `headersorder` successfully reconstructs `tec2`;
- this proves that the malicious server works when the proxy is bypassed.

### 6.3 Individual tests

The project also includes three smaller test scripts:

- `test_server.sh` tests the dedicated-header leak directly on the malicious server, using port `8001`;
- `test_tec1.sh` tests the dedicated-header leak through the proxy, using port `8000`;
- `test_tec2.sh` demonstrates the headers-order technique directly on the server and through the proxy.

Run them with:

```bash
./test_server.sh
./test_tec1.sh
./test_tec2.sh
```

Before each test, the scripts clear the server state with `DELETE /clear`.

---

## 7. Manual demonstration commands

### 7.1 Dedicated header: direct server leak succeeds

```bash
curl -X DELETE http://localhost:8001/clear

curl -X POST http://localhost:8001/setup \
  -H "Content-Type: application/json" \
  -d '{"entrypoint": "demo_direct", "type": "dedicatedheader"}'

curl -X PUT http://localhost:8001/demo_direct \
  -H "X-dataleak: Y2lhbw=="

curl -X GET http://localhost:8001/demo_direct
```

Expected output:

```text
Y2lhbw==
```

### 7.2 Dedicated header: proxy blocks the leak

```bash
curl -X DELETE http://localhost:8001/clear

curl -X POST http://localhost:8000/setup \
  -H "Content-Type: application/json" \
  -d '{"entrypoint": "demo_proxy", "type": "dedicatedheader"}'

curl -X PUT http://localhost:8000/demo_proxy \
  -H "X-dataleak: Y2lhbw=="

curl -X GET http://localhost:8000/demo_proxy
```

Expected output:

```text

```

The empty output means that the proxy forwarded the request but removed the data used by the covert channel.

---

## 8. Extensibility

The implementation is organized around technique-specific modules. The core server and proxy logic dispatch work through registries:

- server-side leak extractors are registered in `EXTRACTORS`;
- proxy-side leak sanitizers are registered in `SANITIZERS`.

This allows a new leak technique to be added without rewriting the HTTP routing logic.

### 8.1 Add a new malicious-server extractor

Create a new module under:

```text
server/modules/
```

The new extractor should implement the same interface used by the existing extractors:

```python
extract(headers, entrypoint, leaked_data, bit_buffers)
```

The extractor receives the HTTP headers, the current entrypoint, the dictionary containing reconstructed values, and the dictionary containing partial bit buffers.

Then register it in the server registry:

```python
EXTRACTORS = {
    "dedicatedheader": DedicatedHeaderExtractor(),
    "headersorder": HeadersOrderExtractor(),
    "newtechnique": NewTechniqueExtractor()
}
```

### 8.2 Add a new proxy sanitizer

Create a new module under:

```text
proxy/modules/
```

The new sanitizer should implement the same interface used by the existing sanitizers:

```python
sanitize(headers_list)
```

The sanitizer receives the request headers as an ordered list of `(key, value)` pairs and must return the sanitized list to forward to the malicious server.

Then register it in the proxy registry:

```python
SANITIZERS = {
    "dedicatedheader": DedicatedHeaderSanitizer(),
    "headersorder": HeadersOrderSanitizer(),
    "newtechnique": NewTechniqueSanitizer()
}
```

### 8.3 Add tests for the new technique

A new technique should include at least:

- one direct-server test proving that the malicious server can reconstruct the data;
- one proxy test proving that the same leak fails when routed through port `8000`.

---

## 9. Project structure

```text
progetto_dataleak/
├── README.md
├── docker-compose.yml
├── group_<groupname>.csv
├── test_complete.sh
├── test_server.sh
├── test_tec1.sh
├── test_tec2.sh
├── proxy/
│   ├── Dockerfile
│   ├── proxy.py
│   ├── requirements.txt
│   └── modules/
│       ├── base_module.py
│       ├── dedicated_header.py
│       └── headers_order.py
└── server/
    ├── Dockerfile
    ├── server.py
    ├── requirements.txt
    └── modules/
        ├── base_module.py
        ├── dedicated_header.py
        └── headers_order.py
```


# Authors
Leonardo Necordi, S5642683
Anna Beardo, S5633630
Luigi Trabucco, S5681875
