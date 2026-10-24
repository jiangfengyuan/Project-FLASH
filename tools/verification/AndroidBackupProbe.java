import com.flash.app.data.Backup;
import org.json.JSONObject;
import org.json.JSONArray;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.time.ZoneId;
import java.util.Objects;

// Run against Gradle-built production Kotlin classes and the existing
// test runtime jars. This is a host JVM codec probe, not Android ART/Room/UI.
public class AndroidBackupProbe {
    static String hash(byte[] bytes) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
    }
    static JSONObject counts(Backup.ImportResult result) {
        return new JSONObject().put("logs", result.getLogs().size())
            .put("emotions", result.getEmotions().size()).put("tasks", result.getTasks().size());
    }
    static void verifyMetadata(JSONObject input, JSONObject output) {
        for (String section : new String[] {"logs", "emotions", "tasks"}) {
            JSONArray incoming = input.getJSONArray(section), outgoing = output.getJSONArray(section);
            for (int i = 0; i < incoming.length(); i++) {
                JSONObject item = incoming.getJSONObject(i), match = null;
                for (int j = 0; j < outgoing.length(); j++) {
                    if (outgoing.getJSONObject(j).getString("id").equals(item.getString("id"))) match = outgoing.getJSONObject(j);
                }
                if (match == null) throw new AssertionError("Incoming record lost");
                for (String field : new String[] {"isFavorite", "intensity", "sourceLogId"}) {
                    Object left = item.opt(field), right = match.opt(field);
                    if (JSONObject.NULL.equals(left)) left = null;
                    if (JSONObject.NULL.equals(right)) right = null;
                    if (!Objects.equals(left, right)) throw new AssertionError("Incoming schema2 metadata changed");
                }
            }
        }
    }
    public static void main(String[] args) throws Exception {
        if (args.length != 3) throw new IllegalArgumentException(
            "Usage: AndroidBackupProbe schema1-seed.json actual-peer-export.json NEW-android-export.json");
        String seed = Files.readString(Path.of(args[0]), StandardCharsets.UTF_8);
        Backup.ImportResult source = Backup.INSTANCE.parseStrict(seed);
        String exported = Backup.INSTANCE.exportJson(source.getLogs(), source.getEmotions(), source.getTasks(),
            "Fictional compatibility verification");
        Backup.ImportResult self = Backup.INSTANCE.parseStrict(exported);
        if (!source.equals(self)) throw new AssertionError("Android self-export changed model fields");
        byte[] exportBytes = exported.getBytes(StandardCharsets.UTF_8);
        Files.write(Path.of(args[2]), exportBytes, StandardOpenOption.CREATE_NEW, StandardOpenOption.WRITE);
        byte[] peerBytes = Files.readAllBytes(Path.of(args[1]));
        JSONObject peer = new JSONObject().put("sha256", hash(peerBytes)).put("bytes", peerBytes.length);
        try {
            Backup.ImportResult received = Backup.INSTANCE.parseStrict(new String(peerBytes, StandardCharsets.UTF_8));
            String reexported = Backup.INSTANCE.exportJson(received.getLogs(), received.getEmotions(), received.getTasks(),
                "Fictional incoming metadata comparison");
            if (!received.equals(Backup.INSTANCE.parseStrict(reexported))) throw new AssertionError("Incoming model changed after re-export");
            verifyMetadata(new JSONObject(new String(peerBytes, StandardCharsets.UTF_8)).getJSONObject("data"),
                new JSONObject(reexported).getJSONObject("data"));
            peer.put("status", "accepted").put("counts", counts(received)).put("incomingMetadataCompared", true);
        } catch (Exception failure) {
            if (!(failure instanceof Backup.BackupFormatException)) throw failure;
            peer.put("status", "rejected").put("error", failure.getMessage());
        }
        JSONArray zones = new JSONArray();
        for (String zone : new String[] {"Europe/Kyiv", "Europe/Kiev", "Asia/Kolkata", "Asia/Calcutta", "UTC", "Invalid/Unknown"}) {
            JSONObject row = new JSONObject().put("input", zone);
            try { row.put("hostJDKZoneId", ZoneId.of(zone).getId()).put("hostJDKAccepted", true); }
            catch (java.time.DateTimeException failure) { row.put("hostJDKAccepted", false); }
            JSONObject input = new JSONObject(seed);
            input.getJSONObject("data").getJSONArray("tasks").getJSONObject(0)
                .getJSONObject("due").put("timeZone", zone);
            try { Backup.INSTANCE.parseStrict(input.toString()); row.put("codecAccepted", true); }
            catch (Exception failure) {
                if (!(failure instanceof Backup.BackupFormatException)) throw failure;
                row.put("codecAccepted", false);
            }
            zones.put(row);
        }
        System.out.println(new JSONObject().put("kind", "Android production Kotlin codec on host JVM")
            .put("nativeAndroid", false).put("hostJava", System.getProperty("java.runtime.version"))
            .put("androidExport", new JSONObject().put("sha256", hash(exportBytes)).put("bytes", exportBytes.length)
                .put("schemas", new JSONObject(exported).getJSONObject("schemas")).put("counts", counts(self)))
            .put("incomingExportToAndroidCodec", peer).put("timezoneProbes", zones).toString(2));
    }
}
