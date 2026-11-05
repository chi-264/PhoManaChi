package dev.phomanachi.phomanachi.apps

import org.junit.Assert.*
import org.junit.Test

class AppPolicyTest {
    @Test fun ordinaryUserAppCanRequestConfirmation() {
        assertEquals(AccessState.AVAILABLE, AppPolicy.uninstall(AppPolicy.Facts()).first)
    }
    @Test fun protectedTargetsCannotBeUninstalled() {
        for (facts in listOf(AppPolicy.Facts(ownApp = true), AppPolicy.Facts(systemApp = true),
            AppPolicy.Facts(coreUid = true), AppPolicy.Facts(essentialDefault = true),
            AppPolicy.Facts(activeAdmin = true), AppPolicy.Facts(userRestricted = true))) {
            assertEquals(AccessState.RESTRICTED, AppPolicy.uninstall(facts).first)
        }
    }
    @Test fun missingProtectionEvidenceFailsClosed() {
        assertEquals(AccessState.UNAVAILABLE, AppPolicy.uninstall(AppPolicy.Facts(protectionKnown = false)).first)
    }
    @Test fun permissionAndHandlerFailuresAreDifferent() {
        assertEquals(AccessState.PERMISSION_REQUIRED, AppPolicy.uninstall(AppPolicy.Facts(permission = false)).first)
        assertEquals(AccessState.UNSUPPORTED, AppPolicy.uninstall(AppPolicy.Facts(handler = false)).first)
    }
    @Test fun staleVersionOrUpdateTimeRequiresAnotherReview() {
        assertTrue(AppPolicy.sameTarget(3, 1000, 3, 1000))
        assertFalse(AppPolicy.sameTarget(3, 1000, 4, 1000))
        assertFalse(AppPolicy.sameTarget(3, 1000, 3, 1001))
    }
    @Test fun onlySystemConfirmationAndAbsenceVerifyRemoval() {
        assertEquals(AppActionPhase.VERIFIED_REMOVED, AppPolicy.outcome(true, false, false).first)
        for (present in listOf(true, null)) assertEquals(AppActionPhase.UNVERIFIED, AppPolicy.outcome(true, false, present).first)
        assertEquals(AppActionPhase.UNVERIFIED, AppPolicy.outcome(false, false, false).first)
    }
    @Test fun cancellationIsNotSuccessAndAmbiguousAbsenceIsNotProof() {
        assertEquals(AppActionPhase.CANCELED, AppPolicy.outcome(false, true, true).first)
        assertEquals(AppActionPhase.UNVERIFIED, AppPolicy.outcome(false, true, false).first)
        assertEquals(AppActionPhase.UNVERIFIED, AppPolicy.outcome(false, true, null).first)
    }
    @Test fun packageIdentifiersCannotInjectUrisOrOtherTargets() {
        for (value in listOf("android", "com.example.app", "dev.phomanachi.phomanachi")) assertTrue(AppPolicy.validPackage(value))
        for (value in listOf("", "package:com.example", "com.example?other=target", "com.example/app", "../escape", "com..example", "a".repeat(256))) assertFalse(AppPolicy.validPackage(value))
    }
}
