{.push stackTrace:off, profiler:off.} ## Ghostify, removing PANIC-messages.

import std/[asyncdispatch, asyncnet, strutils, parseopt, os, net]

type
  ScanConfig = object
    target: string
    startPort: int
    endPort: int
    timeout: int
    batchSize: int
    grabBanners: bool

var conf = ScanConfig(
  target: "",
  startPort: 1, 
  endPort: 10000,
  timeout: 1500,
  batchSize: 1000,
  grabBanners: true
)

proc safeClose(s: AsyncSocket) =
  try: s.close() except: discard

proc getPortAlias(port: int): string =
  case port
  of 21:    "FTP"
  of 22:    "SSH"
  of 23:    "Telnet"
  of 25:    "SMTP"
  of 53:    "DNS"
  of 80, 8080: "HTTP"
  of 135, 445: "SMB/RPC"
  of 143, 993: "IMAP"
  of 443, 8443: "HTTPS"
  of 3306, 5432, 1433: "SQL Database"
  of 3389:  "RDP"
  else:     "Unknown"

proc grabBanner(s: AsyncSocket): Future[string] {.async.} =
  try:
    await sleepAsync(400) 
    let bannerFut = s.recv(1024)
    if await withTimeout(bannerFut, 1000):
      return bannerFut.read().strip()
  except:
    discard
  return ""

proc checkPort(ip: string, port: Port, timeout: int): Future[void] {.async.} =
  var client: AsyncSocket
  try: 
    client = newAsyncSocket() 
  except OSError: 
    return

  try:
    var connectFuture = client.connect(ip, port)
    if await withTimeout(connectFuture, timeout):
      if not connectFuture.failed:
        let alias = getPortAlias(port.int)
        
        let portStr = align($port.int, 5)
        let aliasStr = alignLeft("(" & alias & ")", 14)
        var output = "[X] Port " & portStr & " " & aliasStr & " OPEN"
        
        let speakFirst = [21, 22, 23, 25, 110, 143, 993, 995]
        
        if port.int in speakFirst:
          let banner = await grabBanner(client)
          if banner.len > 0:
            let clean = banner.replace("\r", "").replace("\n", " ").strip()
            output.add(" | Banner: " & clean)
        
        elif port.int in [80, 8080]:
          await client.send("HEAD / HTTP/1.0\r\n\r\n")
          let banner = await grabBanner(client)
          if banner.len > 0:
            let firstLine = banner.splitLines()[0]
            output.add(" | Banner: " & firstLine)

        echo output
  except:
    discard
  finally:
    safeClose(client)

proc parseArguments() =
  var p = initOptParser(quoteShellCommand(commandLineParams()))
  for kind, key, val in p.getopt():
    case kind
    of cmdArgument:
      if conf.target == "": conf.target = key
    of cmdLongOption, cmdShortOption:
      case key
      of "p", "ports":
        if val.contains("-"):
          let parts = val.split("-")
          conf.startPort = parseInt(parts[0])
          conf.endPort = parseInt(parts[1])
        else:
          conf.startPort = parseInt(val)
          conf.endPort = parseInt(val)
      of "t", "timeout": 
        conf.timeout = parseInt(val)
      of "b", "batch": 
        conf.batchSize = parseInt(val)
      of "nobanner": 
        conf.grabBanners = false
      of "h", "help":
        echo "Usage: nimmap <IP> [options]"
        echo "Options: "
        echo "  -p, --ports:START-END   Range of ports"
        echo "  -t, --timeout:MS        Timeout in ms"
        echo "  -b, --batch:SIZE        Batch size"
        echo "  --nobanner              Disable banner grabbing"
        echo "Example: nimmap 127.0.0.1 -p:1-1024 -t:500 -b:1000"
        quit(0)
    of cmdEnd: discard

  if conf.target == "":
    echo "Usage: nimmap <IP> [options]"
    echo "Help: nimmap -h for help"
    quit(0)

proc printLogo() =
  let logo = """
    _   _  _                                     
   | \ | |(_)                                    
   |  \| | _  _ __ ___   _ __ ___    __ _  _ __  
   | . ` || || '_ ` _ \ | '_ ` _ \  / _` || '_ \ 
   | |\  || || | | | | || | | | | || (_| || |_) |
   |_| \_||_||_| |_| |_||_| |_| |_| \__,_|| .__/ 
                                          | |    
            >> ASYNC PORT SCANNER <<      |_|    
              >> by localghost <<
  """
  echo logo    

proc main() {.async.} =
  printLogo()
  parseArguments()
  
  echo "[X] Target: " & conf.target & " (" & $conf.startPort & "-" & $conf.endPort & ")"
  
  if conf.grabBanners: 
    echo "[X] Mode:   Banner Grabbing ON"
  
  var 
    batch: seq[Future[void]] = @[]
    currentPort = conf.startPort

  while currentPort <= conf.endPort:
    while batch.len < conf.batchSize and currentPort <= conf.endPort:
      batch.add(checkPort(conf.target, Port(currentPort), conf.timeout))
      currentPort.inc()
    
    await all(batch)
    batch = @[]
    
    if currentPort mod conf.batchSize == 0:
      let percent = ((currentPort - conf.startPort) * 100 div (conf.endPort - conf.startPort + 1))
      stdout.write("[X] Progress: " & $percent & "%\r")
      stdout.flushFile()

  echo "\n[X] Scan Complete."

when isMainModule:
  waitFor main()