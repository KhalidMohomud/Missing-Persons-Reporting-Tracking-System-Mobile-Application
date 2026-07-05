const String URL_BASE = "http://localhost:3003/api/v1";

const String LOGIN_URL = "$URL_BASE/user/signin";
const String REGISTER_URL = "$URL_BASE/user/signup";
const String socialLOGIN_URL = "$URL_BASE/user/socialsignin";

const String MISSING_REPORTS_URL = "$URL_BASE/missingreports";
const String FOUND_REPORTS_URL = "$URL_BASE/foundreports";
const String MONTHLY_REPORTS_URL = "$URL_BASE/reports/monthly";
const String YEARLY_REPORTS_URL = "$URL_BASE/reports/yearly";
const String USERS_URL = "$URL_BASE/user";
const String TIPS_URL = "$URL_BASE/tips";
const String ALERTS_URL = "$URL_BASE/alerts";
const String FCM_TOKEN_URL = "$URL_BASE/user/fcm-token";
const String USER_LOCATION_URL = "$URL_BASE/user/location";

String verificationStatusUrl(String reportId) =>
    "$URL_BASE/missingreports/$reportId/verification";

String verificationMessagesUrl(String reportId) =>
    "$URL_BASE/missingreports/$reportId/verification/messages";

String verificationRequestEvidenceUrl(String reportId) =>
    "$URL_BASE/missingreports/$reportId/verification/request-evidence";

String verificationVerifyUrl(String reportId) =>
    "$URL_BASE/missingreports/$reportId/verification/verify";

String verificationRejectUrl(String reportId) =>
    "$URL_BASE/missingreports/$reportId/verification/reject";
