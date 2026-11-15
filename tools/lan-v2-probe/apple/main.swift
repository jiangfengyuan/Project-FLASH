import CFlashLanProbe

let result = flash_lan_probe_run()
precondition(result == 0, "LAN build probe failed (code \(result))")
print("LAN build probe: PASS (not production pairing)")
