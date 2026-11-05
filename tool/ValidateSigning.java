import java.io.File;
import java.security.Key;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.util.Arrays;

/** Check signing secrets without printing credentials or exporting private keys. */
class ValidateSigning {
    private static String required(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) {
            fail("Missing signing setting: " + name + ".");
        }
        return value;
    }

    private static void fail(String message) {
        System.err.println(message);
        System.exit(1);
    }

    public static void main(String[] args) {
        File file = new File(required("PHOMANACHI_KEYSTORE_PATH"));
        String alias = required("PHOMANACHI_KEY_ALIAS");
        char[] storePassword = required("PHOMANACHI_STORE_PASSWORD").toCharArray();
        char[] keyPassword = required("PHOMANACHI_KEY_PASSWORD").toCharArray();
        try {
            KeyStore store;
            try {
                // Detect JKS/PKCS12 by contents; the filename extension is irrelevant.
                store = KeyStore.getInstance(file, storePassword);
            } catch (Exception error) {
                fail("Cannot open signing keystore. Check PHOMANACHI_KEYSTORE_BASE64 and PHOMANACHI_STORE_PASSWORD; re-encode the original keystore file if needed.");
                return;
            }
            try {
                if (!store.containsAlias(alias) || !store.isKeyEntry(alias)) {
                    fail("PHOMANACHI_KEY_ALIAS does not identify a private-key entry in this keystore.");
                }
                Key key;
                try {
                    key = store.getKey(alias, keyPassword);
                } catch (Exception error) {
                    fail("Cannot unlock signing key. Check PHOMANACHI_KEY_PASSWORD matches the private key in the uploaded keystore.");
                    return;
                }
                if (!(key instanceof PrivateKey) || store.getCertificateChain(alias) == null) {
                    fail("Signing entry must contain a private key and certificate chain.");
                }
            } catch (Exception error) {
                fail("Cannot read signing entry. Check the original keystore and signing settings.");
            }
            System.out.println("Signing keystore, alias, and key password verified.");
        } finally {
            Arrays.fill(storePassword, '\0');
            Arrays.fill(keyPassword, '\0');
        }
    }
}
