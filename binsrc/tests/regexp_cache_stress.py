"""Stress regexp cache eviction on an isolated instance and verify every result."""

import argparse
import concurrent.futures
import http.client
import json
import time
import urllib.parse


def run_worker(worker: int, args: argparse.Namespace) -> tuple[int, int]:
    """Mix unique and shared patterns to exercise insertion, lookup and eviction."""
    connection = http.client.HTTPConnection("127.0.0.1", args.port, timeout=60)
    completed = 0
    evaluations = 0
    try:
        for index in range(worker, args.requests, args.workers):
            rows = []
            # Exercise both matching and nonmatching inputs for every generated pattern.
            for offset in range(8):
                for token in (f"unique-{args.round}-{index}-{offset}",
                              f"shared-{args.round}-{index // args.workers}-{offset}"):
                    pattern = f"^(?:{token}|alternate-{token})$"
                    rows.append(f'("{token}" "{pattern}" "" true)')
                    rows.append(f'("wrong-{token}" "{pattern}" "" false)')
            rows.extend(['("HOT" "^hot$" "i" true)',
                         '("HOT" "^hot$" "" false)',
                         '("caf\u00e9" "^caf\u00e9$" "" true)'])
            query = (
                "SELECT (SUM(IF(REGEX(?text, ?pattern, ?flags) = ?expected, 0, 1)) AS ?errors) "
                "WHERE { VALUES (?text ?pattern ?flags ?expected) { "
                + " ".join(rows) + " } }"
            )
            body = urllib.parse.urlencode({
                "query": query, "format": "application/sparql-results+json"
            })
            connection.request("POST", "/sparql", body, {
                "Content-Type": "application/x-www-form-urlencoded",
            })
            response = connection.getresponse()
            data = response.read()
            if response.status != 200:
                raise RuntimeError(f"HTTP {response.status}: {data[:500]!r}")
            bindings = json.loads(data)["results"]["bindings"]
            if len(bindings) != 1 or int(bindings[0]["errors"]["value"]) != 0:
                raise AssertionError(f"Incorrect REGEX results at request {index}: {bindings}")
            completed += 1
            evaluations += len(rows)
            if worker == 0 and completed % 100 == 0:
                print(f"Progress: approximately {completed * args.workers}/{args.requests} requests", flush=True)
    finally:
        connection.close()
    return completed, evaluations


def main() -> None:
    """Require an explicit test endpoint and fail on any request or result error."""
    parser = argparse.ArgumentParser(
        description="Stress a Virtuoso regexp cache; use an isolated test instance only"
    )
    parser.add_argument("--port", type=int, required=True, help="HTTP port of an isolated test instance")
    parser.add_argument("--workers", type=int, default=64)
    parser.add_argument("--requests", type=int, default=20000)
    parser.add_argument("--round", type=int, default=1)
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("Port must be between 1 and 65535")
    if args.workers < 1 or args.requests < 1:
        parser.error("Workers and requests must be positive")
    started = time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = [executor.submit(run_worker, worker, args) for worker in range(args.workers)]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]
    print(json.dumps({
        "status": "PASS", "requests": sum(result[0] for result in results),
        "regex_evaluations": sum(result[1] for result in results),
        "unique_patterns_min": args.requests * 8,
        "workers": args.workers, "seconds": round(time.monotonic() - started, 2),
    }), flush=True)


if __name__ == "__main__":
    main()
