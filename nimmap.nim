{.push stackTrace:off, profiler:off.}

import std/[asyncdispatch, asyncnet, strutils, parseopt, os, net]

type
  ScanConfig = object
    target: string
    startPort: int
    endPort: int
    timeout: int
    batchSize: int
    grabBanners: bool
    outputFile: string # New: File output path

var conf = ScanConfig(
  target: "",
  startPort: 1, 
  endPort: 10000,
  timeout: 1000,
  batchSize: 300, 
  grabBanners: true,
  outputFile: ""
)

proc safeClose(s: AsyncSocket) =
  try: s.close() except: discard

proc getPortAlias(port: int): string =
  case port
  of 21, 2121: "FTP"
  of 22:       "SSH"
  of 23:       "Telnet"
  of 25:       "SMTP"
  of 53:       "DNS"
  of 80, 8080, 8180: "HTTP"
  of 111:      "RPCbind"
  of 135, 139, 445: "SMB/RPC"
  of 143, 993: "IMAP"
  of 443, 8443: "HTTPS"
  of 1099:     "Java RMI"
  of 1524:     "Ingreslock (Shell)" 
  of 3306, 5432, 1433: "SQL Database"
  of 3389:     "RDP"
  of 5900:     "VNC"
  of 6200:     "vsftpd Backdoor"
  of 6667:     "IRC"
  else:        "Unknown"

proc grabBanner(s: AsyncSocket): Future[string] {.async.} =
  try:
    await sleepAsync(200) 
    let bannerFut = s.recv(1024)
    if await withTimeout(bannerFut, 1000):
      return bannerFut.read().strip()
  except:
    discard
  return ""

# Changed return type from void to string
proc checkPort(ip: string, port: Port, timeout: int): Future[string] {.async.} =
  var client: AsyncSocket
  try: 
    client = newAsyncSocket() 
  except OSError: 
    return "[X] OS Error creating socket for port " & $port.int

  try:
    var connectFuture = client.connect(ip, port)
    if await withTimeout(connectFuture, timeout):
      if not connectFuture.failed:
        let alias = getPortAlias(port.int)
        
        let portStr = align($port.int, 5)
        let aliasStr = alignLeft("(" & alias & ")", 20)
        var output = "[+] Port " & portStr & " " & aliasStr & " OPEN"
        
        if conf.grabBanners:
          let speakFirst = [21, 22, 23, 25, 110, 143, 993, 995, 2121, 5900, 6667, 1524, 6200]
          
          if port.int in speakFirst:
            let banner = await grabBanner(client)
            if banner.len > 0:
              let clean = banner.replace("\r", "").replace("\n", " ").strip()
              output.add(" | Banner: " & clean)
          
          elif port.int in [80, 8080, 8180]:
            await client.send("HEAD / HTTP/1.0\r\n\r\n")
            let banner = await grabBanner(client)
            if banner.len > 0:
              let firstLine = banner.splitLines()[0]
              output.add(" | Banner: " & firstLine)

        return output # Return the string instead of echoing directly
  except:
    discard
  finally:
    safeClose(client)
    
  return "" 

proc parseArguments() =
  var p = initOptParser()
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
      of "o", "output":
        conf.outputFile = val
      of "nobanner": 
        conf.grabBanners = false
      of "h", "help":
        echo "Usage: nimmap <IP> [options]"
        echo "Options: "
        echo "  -p, --ports:START-END   Range of ports"
        echo "  -t, --timeout:MS        Timeout in ms"
        echo "  -b, --batch:SIZE        Batch size (default 300)"
        echo "  -o, --output:FILE       Save results to a file"
        echo "  --nobanner              Disable banner grabbing"
        echo "Example: nimmap 127.0.0.1 -p:1-1024 -o:scan_results.txt"
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
  
  echo "[*] Target: " & conf.target & " (" & $conf.startPort & "-" & $conf.endPort & ")"
  if conf.grabBanners: echo "[*] Mode:   Banner Grabbing ON"
  if conf.outputFile != "": echo "[*] Output: " & conf.outputFile
  echo ""
  
  var 
    batch: seq[Future[string]] = @[] 
    currentPort = conf.startPort
    allFoundPorts: seq[string] = @[] 

  while currentPort <= conf.endPort:
    while batch.len < conf.batchSize and currentPort <= conf.endPort:
      batch.add(checkPort(conf.target, Port(currentPort), conf.timeout))
      currentPort.inc()
    
    let batchResults = await all(batch) 
    batch = @[]
    
    for result in batchResults:
      if result != "":
        allFoundPorts.add(result)
        stdout.write("\r" & " ".repeat(60) & "\r") 
        echo result

    let percent = ((currentPort - 1 - conf.startPort) * 100 div (conf.endPort - conf.startPort + 1))
    stdout.write("[*] Progress: " & $percent & "%\r")
    stdout.flushFile()

  stdout.write("\r" & " ".repeat(60) & "\r") 
  echo "[*] Scan Complete."
  
  if conf.outputFile != "" and allFoundPorts.len > 0:
    try:
      var fileContent = "Scan Results for " & conf.target & "\n"
      fileContent &= strutils.repeat('=', 40) & "\n"
      for line in allFoundPorts:
        fileContent &= line & "\n"
      
      writeFile(conf.outputFile, fileContent)
      echo "[*] Results saved successfully to ", conf.outputFile
    except IOError:
      echo "[X] Failed to write to output file: ", conf.outputFile

when isMainModule:
  waitFor main()
