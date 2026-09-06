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
  static const String transactionCharge = 'https://dishi.delstarfordworks.co.ke/api/v1/transaction/charge';
  static const String transactionSos = 'https://dishi.delstarfordworks.co.ke/api/v1/transaction/sos';
  static const String transactionCashout = 'https://dishi.delstarfordworks.co.ke/api/v1/transaction/cashout';
}
