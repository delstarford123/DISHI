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
  static const String mpesaCheckStatus = '$baseUrl/api/v1/mpesa/check_status';
  
  // Transaction endpoints
  static const String transactionCharge = '$baseUrl/api/v1/transaction/charge';
  static const String transactionSos = '$baseUrl/api/v1/transaction/sos';
  static const String transactionCashout = '$baseUrl/api/v1/transaction/cashout';
  static const String transactionTopup = '$baseUrl/api/v1/transaction/topup';
  static const String transactionParentTransfer = '$baseUrl/api/v1/transaction/parent_transfer';
  static const String transactionP2PTransfer = '$baseUrl/api/v1/transaction/p2p_transfer';
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

  // ==========================================
  // Version 6 (v6) Endpoints - Pan-African Campus Commerce Ecosystem
  // ==========================================
  static const String v6Base = '$baseUrl/api/v6';
  static const String campusGigs = '$v6Base/campus_gigs';
  static const String campusGigsRegister = '$campusGigs/register';
  static const String campusGigsRequest = '$campusGigs/request';
  static const String campusGigsAccept = '$campusGigs/accept';
  static const String campusGigsVerifyHandoff = '$campusGigs/verify_handoff';
  static const String campusGigsComplete = '$campusGigs/complete';
  static const String campusGigsRefundEscrow = '$campusGigs/refund_escrow';

  // V6 Pan-African & Regional Vendor Discovery
  static const String vendorsV6 = '$v6Base/vendors';
  static const String vendorsSearchV6 = '$vendorsV6/search';
  static const String vendorsRegionsV6 = '$vendorsV6/regions';

  // V6 Pillar 1: Campus Commerce, Supermarkets & Barcode Scanning
  static const String v6Commerce = '$v6Base/commerce';
  static const String v6Categories = '$v6Commerce/categories';
  static const String v6VendorsByCategory = '$v6Commerce/vendors';
  static const String v6BarcodeLookup = '$v6Commerce/barcode';
  static const String v6BarcodeRegister = '$v6Commerce/barcode/register';
  static const String v6InstallmentsCreate = '$v6Commerce/installments/create';
  static const String v6FlashDeals = '$v6Commerce/flash_deals';
  static const String v6PoolCreate = '$v6Commerce/pool/create';
  static const String v6WarrantyVerify = '$v6Commerce/warranty';
  static const String v6WholesaleCatalog = '$v6Commerce/wholesale/catalog';

  // V6 Pillar 2: Student-Parent Financial & Health Synchrony
  static const String v6ParentSync = '$v6Base/parent_sync';
  static const String v6PurposeTransfer = '$v6ParentSync/purpose_transfer';
  static const String v6CartPaylink = '$v6ParentSync/cart/create_paylink';
  static const String v6NutritionDigest = '$v6ParentSync/nutrition_digest';
  static const String v6LowBalanceSos = '$v6ParentSync/sos_allowance';
  static const String v6SpendingLimits = '$v6ParentSync/limits';
  static const String v6TuitionDisburse = '$v6ParentSync/tuition_vault/disburse';
  static const String v6TuitionVaultDisburse = v6TuitionDisburse;

  // V6 Pillar 3 & 5: Smart Logistics, Dynamic QR Tokens & Safety
  static const String v6Logistics = '$v6Base/logistics';
  static const String v6QrToken = '$v6Logistics/qr_token';
  static const String v6ValidateToken = '$v6Logistics/validate_token';
  static const String v6ValidatePickupToken = v6ValidateToken;
  static const String v6DineInOrder = '$v6Logistics/dine_in/order';
  static const String v6SubscriptionConsume = '$v6Logistics/subscription/consume';
  static const String v6OkoaMealRequest = '$v6Logistics/safety/okoa_meal/request';
  static const String v6SplitExpenseCreate = '$v6Logistics/social/split_expense/create';
  static const String v6SkuLookup = v6BarcodeLookup;

  // V6 Conversational Voice Assistant ("Sema na DISHI")
  static const String v6Voice = '$v6Base/voice';
  static const String v6VoiceIntent = '$v6Voice/intent';
}
