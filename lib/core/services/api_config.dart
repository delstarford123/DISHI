class ApiConfig {
  // Staging/V2 domain mapped to the new Vercel backend deployment
  static const String baseUrl = 'https://dishi.delstarfordworks.co.ke';
  
  // Endpoints structure derived from backend
  static const String authLogin = '$baseUrl/api/v1/auth/login';
  static const String authRegister = '$baseUrl/api/v1/auth/register';
  static const String authPinSendOtp = '$baseUrl/api/v1/auth/pin/otp/send';
  static const String authPinVerifyOtp = '$baseUrl/api/v1/auth/pin/otp/verify';
  static const String authPinReset = '$baseUrl/api/v1/auth/pin/reset';
  
  static const String housingV2 = '$baseUrl/v2/housing';
  static const String housingV2Apply = '$housingV2/apply';
  static const String housingV2Exit = '$housingV2/exit';
  
  // M-PESA endpoints
  static const String mpesaWithdraw = '$baseUrl/api/v1/mpesa/b2c';
  static const String mpesaStkPush = '$baseUrl/api/v1/mpesa/stkpush';
  
  // Transaction endpoints
  static const String transactionCharge = '$baseUrl/api/v1/transaction/charge';
  static const String transactionSos = '$baseUrl/api/v1/transaction/sos';
  static const String transactionCashout = '$baseUrl/api/v1/transaction/cashout';
  static const String transactionTopup = '$baseUrl/api/v1/transaction/topup';
  static const String transactionParentTransfer = '$baseUrl/api/v1/transaction/parent_transfer';
  static const String transactionPreorder = '$baseUrl/api/v1/transaction/preorder';
  static const String transactionPreorderCancel = '$baseUrl/api/v1/transaction/preorder/cancel';
  static const String vendorAgentTopup = '$baseUrl/api/v4/vendor/topup';
  
  // V4 Parent Services (0% Commission Guaranteed)
  static const String parentV4 = '$baseUrl/api/v4/parent';
  static const String parentV4FundStudent = '$parentV4/fund_student';
  static const String parentV4FundVault = '$parentV4/fund_vault';
  static const String parentV4Transfer = '$parentV4/transfer';
  static const String parentV4BulkFund = '$parentV4/bulk_fund';
  static const String parentV4FeePolicy = '$parentV4/fee_policy';
  
  // Games Hub endpoints
  static const String gamesScore = '$baseUrl/api/v1/games/score';
  static const String gamesSpin = '$baseUrl/api/v1/games/spin';
  static const String gamesRedeem = '$baseUrl/api/v1/games/redeem';
  static const String gamesEntry = '$baseUrl/api/v1/games/entry';
  static const String gamesUnlock = '$baseUrl/api/v1/games/unlock';
}
