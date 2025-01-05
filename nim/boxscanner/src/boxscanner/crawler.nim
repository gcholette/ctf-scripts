import std/[strformat, strutils, terminal, xmltree, strtabs, uri]
import pkg/htmlparser
import fingerprint
from puppy import fetch, get, Request, parseUrl

type
  CrawlStatus* {.pure.} = enum 
    success, failure, skipped

type
  CrawlPageResult = object
    status*: CrawlStatus
    httpCode: int
    host: string
    port: int
    route: string
    contents: string

proc findLinksInPage(htmlContents: string, hostname: string): seq[string] = 
  let html = parseHtml(htmlContents)

  for s in html.findAll("script"):
    if s.attrs != nil and s.attrs.hasKey "src":
      let uri = parseUri(s.attrs["src"])
      if uri.hostname.len > 0:
        if uri.hostname.endsWith(".htb"):
          fgGreen.styledEcho &"Found one <script> {uri.hostname}"

  for a in html.findAll("a"):
    if a.attrs != nil and a.attrs.hasKey "href":
      let uri = parseUri(a.attrs["href"])
      if uri.hostname.len > 0:
        if uri.hostname.endsWith(".htb"):
          fgGreen.styledEcho &"Found one <script> {uri.hostname}"

proc crawl*(host: string, port: int): CrawlPageResult =
  try:
    let svc = fingerprintPort(host,  port)
    case svc:
      of http, https:
        var proto = if svc == http: "http" else: "https"

        let response = fetch(Request(          
          url: parseUrl(&"{proto}://{host}:{port}"),
          verb: "get",
          allowAnyHttpsCertificate: true
        ))

        discard response.body.findLinksInPage host

        return CrawlPageResult(
          status: success, 
          contents: response.body, 
          httpCode: response.code, 
          host: host, 
          port: port, 
          route: "/"
        )
      else:
        return CrawlPageResult(status: skipped, contents: "")

  except:
    styledEcho(fgRed, &"Could not crawl {host}:{port}")
    return CrawlPageResult(
      status: failure, 
      contents: "", 
      httpCode: -1, 
      host: host, 
      port: port, 
      route: "/"
    )

