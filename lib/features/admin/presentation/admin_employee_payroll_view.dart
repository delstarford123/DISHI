import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/admin_service.dart';
import 'admin_b2b_finance_view.dart';
import 'admin_c2b_collections_view.dart';

// -- CUSTOM EXECUTIVE THEME COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonBlue = Color(0xFF3B82F6);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonRed = Color(0xFFFF2A6D);
const Color _textSecondary = Color(0xFF8B9BB4);

class AdminEmployeePayrollView extends StatefulWidget {
  const AdminEmployeePayrollView({super.key});

  @override
  State<AdminEmployeePayrollView> createState() => _AdminEmployeePayrollViewState();
}

class _AdminEmployeePayrollViewState extends State<AdminEmployeePayrollView> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _employees = [];
  Map<String, dynamic> _payrollSummary = {};
  List<dynamic> _payrollSlips = [];

  String _searchQuery = '';
  String _selectedDeptFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _adminService.getEmployees(),
        _adminService.getPayrollSummary(),
        _adminService.getPayrollSlips(),
      ]);

      if (mounted) {
        setState(() {
          _employees = results[0] as List<dynamic>;
          _payrollSummary = results[1] as Map<String, dynamic>;
          _payrollSlips = results[2] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard'), backgroundColor: _neonCyan, duration: const Duration(seconds: 2)),
    );
  }

  // --- ADD EMPLOYEE MODAL ---
  void _showAddEmployeeModal({Map<String, dynamic>? existingEmp}) {
    final bool isEditing = existingEmp != null;
    final nameCtrl = TextEditingController(text: existingEmp?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: existingEmp?['phone'] ?? '');
    final salaryCtrl = TextEditingController(text: (existingEmp?['base_salary'] ?? '').toString());
    final roleCtrl = TextEditingController(text: existingEmp?['role'] ?? 'Staff');
    final idCtrl = TextEditingController(text: existingEmp?['national_id'] ?? '');
    final shifCtrl = TextEditingController(text: (existingEmp?['shif_deduction'] ?? '0').toString());
    final nssfCtrl = TextEditingController(text: (existingEmp?['nssf_deduction'] ?? '0').toString());
    final housingCtrl = TextEditingController(text: (existingEmp?['housing_levy'] ?? '0').toString());

    String selectedDept = existingEmp?['department'] ?? 'Delivery Fleet';
    String selectedSalaryType = existingEmp?['salary_type'] ?? 'MONTHLY';
    final departments = ['Delivery Fleet', 'Kitchen Staff', 'Caretakers', 'Security', 'Operations', 'Tech/IT'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEditing ? 'Edit Employee Record' : 'Register New Employee', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: _textSecondary), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'M-PESA Phone (e.g. 254712345678)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: salaryCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Base Salary (KES)',
                          labelStyle: const TextStyle(color: _textSecondary),
                          filled: true,
                          fillColor: _surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: roleCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Job Title / Role',
                          labelStyle: const TextStyle(color: _textSecondary),
                          filled: true,
                          fillColor: _surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Department:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: departments.map((dept) {
                    final isSel = selectedDept == dept;
                    return ChoiceChip(
                      label: Text(dept, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: isSel,
                      selectedColor: _neonCyan,
                      backgroundColor: _surfaceLight,
                      onSelected: (val) => setSheetState(() => selectedDept = dept),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Statutory Deductions (Optional):', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nssfCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'NSSF (KES)',
                          labelStyle: const TextStyle(color: _textSecondary, fontSize: 11),
                          filled: true,
                          fillColor: _surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: shifCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'SHIF (KES)',
                          labelStyle: const TextStyle(color: _textSecondary, fontSize: 11),
                          filled: true,
                          fillColor: _surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: housingCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Housing Levy',
                          labelStyle: const TextStyle(color: _textSecondary, fontSize: 11),
                          filled: true,
                          fillColor: _surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final sal = double.tryParse(salaryCtrl.text.trim());
                    if (name.isEmpty || phone.isEmpty || sal == null || sal <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid name, phone, and salary')));
                      return;
                    }
                    Navigator.pop(context);
                    final payload = {
                      'name': name,
                      'phone': phone,
                      'base_salary': sal,
                      'role': roleCtrl.text.trim(),
                      'department': selectedDept,
                      'salary_type': selectedSalaryType,
                      'national_id': idCtrl.text.trim(),
                      'nssf_deduction': double.tryParse(nssfCtrl.text.trim()) ?? 0.0,
                      'shif_deduction': double.tryParse(shifCtrl.text.trim()) ?? 0.0,
                      'housing_levy': double.tryParse(housingCtrl.text.trim()) ?? 0.0,
                    };

                    try {
                      if (isEditing) {
                        await _adminService.updateEmployee(existingEmp['id'], payload);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee updated successfully'), backgroundColor: _neonCyan));
                      } else {
                        await _adminService.addEmployee(payload);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee registered successfully'), backgroundColor: _neonCyan));
                      }
                      _fetchAllData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed));
                    }
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Register Employee', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- DISBURSE SALARY B2C MODAL ---
  void _showDisburseModal(Map<String, dynamic> emp) {
    final bonusCtrl = TextEditingController(text: '0');
    final advanceCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController(text: 'Monthly Salary Disbursement');

    final baseSalary = (emp['base_salary'] as num?)?.toDouble() ?? 0.0;
    final nssf = (emp['nssf_deduction'] as num?)?.toDouble() ?? 0.0;
    final shif = (emp['shif_deduction'] as num?)?.toDouble() ?? 0.0;
    final housing = (emp['housing_levy'] as num?)?.toDouble() ?? 0.0;
    final fixedDeductions = nssf + shif + housing;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bonus = double.tryParse(bonusCtrl.text.trim()) ?? 0.0;
          final advance = double.tryParse(advanceCtrl.text.trim()) ?? 0.0;
          final net = (baseSalary + bonus) - (fixedDeductions + advance);

          return AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan, width: 1.5)),
            title: Row(
              children: [
                const Icon(Icons.send_rounded, color: _neonCyan),
                const SizedBox(width: 8),
                Expanded(child: Text('Pay Salary: ${emp["name"]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Phone: ${emp["phone"]} • Dept: ${emp["department"]}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        _buildPayRow('Base Salary', 'KES ${baseSalary.toStringAsFixed(2)}', Colors.white),
                        if (fixedDeductions > 0) _buildPayRow('Statutory Deductions (NSSF/SHIF)', '- KES ${fixedDeductions.toStringAsFixed(2)}', _neonRed),
                        const Divider(color: Colors.white12),
                        _buildPayRow('Net Disbursement', 'KES ${net.toStringAsFixed(2)}', _neonCyan, isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: bonusCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: '+ Bonus',
                            labelStyle: const TextStyle(color: _textSecondary, fontSize: 11),
                            filled: true,
                            fillColor: _surfaceLight,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: advanceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: '- Advance Loan',
                            labelStyle: const TextStyle(color: _textSecondary, fontSize: 11),
                            filled: true,
                            fillColor: _surfaceLight,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Remarks / Month',
                      labelStyle: const TextStyle(color: _textSecondary, fontSize: 11),
                      filled: true,
                      fillColor: _surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final res = await _adminService.disburseSalaryB2C(
                      employeeId: emp['id'],
                      bonus: double.tryParse(bonusCtrl.text.trim()) ?? 0.0,
                      advanceDeduction: double.tryParse(advanceCtrl.text.trim()) ?? 0.0,
                      notes: notesCtrl.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res['message'] ?? 'Salary payment queued!'), backgroundColor: _neonCyan),
                      );
                      _fetchAllData();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Disbursement Failed: $e'), backgroundColor: _neonRed),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.flash_on, size: 16),
                label: const Text('Disburse via M-PESA B2C', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- BULK DISBURSE MODAL ---
  void _showBulkDisburseModal() {
    String selectedDept = 'ALL';
    final departments = ['ALL', 'Delivery Fleet', 'Kitchen Staff', 'Caretakers', 'Security', 'Operations', 'Tech/IT'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan, width: 2)),
          title: const Row(
            children: [
              Icon(Icons.groups_rounded, color: _neonCyan),
              SizedBox(width: 8),
              Text('Bulk Departmental Payroll', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Execute batch M-PESA salary disbursements for all active staff in the selected department:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: departments.map((dept) {
                  final isSel = selectedDept == dept;
                  return ChoiceChip(
                    label: Text(dept, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    selected: isSel,
                    selectedColor: _neonCyan,
                    backgroundColor: _surfaceLight,
                    onSelected: (val) => setDialogState(() => selectedDept = dept),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final res = await _adminService.bulkDisbursePayroll(department: selectedDept == 'ALL' ? null : selectedDept);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['message'] ?? 'Batch payroll processed!'), backgroundColor: _neonCyan),
                    );
                    _fetchAllData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Bulk Run Failed: $e'), backgroundColor: _neonRed),
                    );
                  }
                }
              },
              child: const Text('Execute Batch Payout', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Employee Management & Payroll (B2C)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: _neonBlue),
            tooltip: 'M-PESA B2B Finance',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminB2BFinanceView())),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, color: _neonOrange),
            tooltip: 'C2B Paybill Inbound',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminC2BCollectionsView())),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: _neonCyan),
            tooltip: 'Refresh Data',
            onPressed: _fetchAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _neonCyan,
          labelColor: _neonCyan,
          unselectedLabelColor: _textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.badge), text: 'Staff Directory'),
            Tab(icon: Icon(Icons.payments), text: 'Payroll Engine'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Payslip History'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: _neonCyan,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Staff', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showAddEmployeeModal(),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : _errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStaffDirectoryTab(),
                    _buildPayrollEngineTab(),
                    _buildPayslipsTab(),
                  ],
                ),
    );
  }

  // --- TAB 1: STAFF DIRECTORY ---
  Widget _buildStaffDirectoryTab() {
    final filtered = _employees.where((emp) {
      final name = (emp['name'] ?? '').toString().toLowerCase();
      final phone = (emp['phone'] ?? '').toString().toLowerCase();
      final dept = (emp['department'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery) || phone.contains(_searchQuery);
      if (!matchesSearch) return false;

      if (_selectedDeptFilter == 'ALL') return true;
      return dept == _selectedDeptFilter.toLowerCase();
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search staff by name or phone...',
                  hintStyle: const TextStyle(color: _textSecondary),
                  prefixIcon: const Icon(Icons.search, color: _textSecondary),
                  filled: true,
                  fillColor: _surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['ALL', 'Delivery Fleet', 'Kitchen Staff', 'Caretakers', 'Security', 'Operations', 'Tech/IT'].map((dept) {
                    final isSel = _selectedDeptFilter == dept;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(dept, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        selected: isSel,
                        selectedColor: _neonCyan,
                        backgroundColor: _surfaceLight,
                        onSelected: (val) => setState(() => _selectedDeptFilter = dept),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, color: _textSecondary, size: 48),
                      const SizedBox(height: 12),
                      const Text('No employees found matching filter.', style: TextStyle(color: _textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final emp = filtered[idx] as Map<String, dynamic>;
                    final name = emp['name'] ?? 'Unknown';
                    final phone = emp['phone'] ?? 'N/A';
                    final dept = emp['department'] ?? 'General';
                    final role = emp['role'] ?? 'Staff';
                    final salary = (emp['base_salary'] as num?)?.toDouble() ?? 0.0;
                    final status = emp['status'] ?? 'active';
                    final isSuspended = status == 'suspended';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSuspended ? _neonRed : _surfaceLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: _surfaceLight,
                                child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text('$role • $dept', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isSuspended ? _neonRed : Colors.greenAccent).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(status.toUpperCase(), style: TextStyle(color: isSuspended ? _neonRed : Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('M-PESA: $phone', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              Text('KES ${salary.toStringAsFixed(2)} / mo', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: _surfaceLight)),
                                onPressed: () => _showAddEmployeeModal(existingEmp: emp),
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('Edit', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                                onPressed: () => _showDisburseModal(emp),
                                icon: const Icon(Icons.send_rounded, size: 14),
                                label: const Text('Pay Salary (B2C)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB 2: PAYROLL ENGINE ---
  Widget _buildPayrollEngineTab() {
    final activeCount = _payrollSummary['active_employees'] ?? 0;
    final liability = (_payrollSummary['monthly_liability'] as num?)?.toDouble() ?? 0.0;
    final paidThisMonth = (_payrollSummary['paid_this_month'] as num?)?.toDouble() ?? 0.0;
    final pending = (_payrollSummary['pending_payout'] as num?)?.toDouble() ?? 0.0;
    final cycle = _payrollSummary['current_cycle'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Cards
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _neonCyan.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payroll Cycle:', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text(cycle, style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Total Monthly Payroll Liability', style: TextStyle(color: _textSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              Text('KES ${liability.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Disbursed via B2C', style: TextStyle(color: _textSecondary, fontSize: 11)),
                        Text('KES ${paidThisMonth.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pending Clearance', style: TextStyle(color: _textSecondary, fontSize: 11)),
                        Text('KES ${pending.toStringAsFixed(2)}', style: const TextStyle(color: _neonOrange, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Bulk Disbursement Trigger Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _neonCyan.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, color: _neonCyan, size: 22),
                  SizedBox(width: 8),
                  Text('Bulk Batch Salary Engine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Simultaneously dispatch salaries to all $activeCount active employees across departments via Safaricom Daraja B2C queue.',
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _neonCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _showBulkDisburseModal,
                icon: const Icon(Icons.flash_on),
                label: const Text('Initiate Bulk Batch Run', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Statutory & Tax Compliance Info
        const Text('Kenyan Statutory Payroll Compliance', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildComplianceTile('National Social Security Fund (NSSF)', 'Tier I & II auto-deduction configured per employee card'),
        const SizedBox(height: 8),
        _buildComplianceTile('Social Health Insurance Fund (SHIF)', '2.75% gross calculation support for health cover'),
        const SizedBox(height: 8),
        _buildComplianceTile('Affordable Housing Levy (AHL)', '1.5% deduction framework for statutory compliance'),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildComplianceTile(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _surfaceLight)),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: _neonCyan, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: _textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: PAYSLIP HISTORY ---
  Widget _buildPayslipsTab() {
    if (_payrollSlips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, color: _textSecondary, size: 48),
            const SizedBox(height: 12),
            const Text('No payslips recorded yet.', style: TextStyle(color: _textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payrollSlips.length,
      itemBuilder: (context, idx) {
        final slip = _payrollSlips[idx] as Map<String, dynamic>;
        final empName = slip['employee_name'] ?? 'Staff Member';
        final dept = slip['department'] ?? 'General';
        final month = slip['month'] ?? '';
        final net = (slip['net_salary'] as num?)?.toDouble() ?? 0.0;
        final gross = (slip['gross_salary'] as num?)?.toDouble() ?? net;
        final convId = slip['conversation_id'] ?? slip['id'] ?? 'N/A';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _surfaceLight)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(empName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('KES ${net.toStringAsFixed(2)}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 4),
              Text('$dept • Cycle: $month', style: const TextStyle(color: _textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Gross: KES ${gross.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  InkWell(
                    onTap: () => _copyToClipboard(convId, 'Ref ID'),
                    child: Text('Ref: ${convId.length > 12 ? convId.substring(0, 12) : convId}', style: const TextStyle(color: _neonBlue, fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: _neonRed, size: 54),
            const SizedBox(height: 16),
            const Text('Payroll Module Error', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Failed to load employee records', style: const TextStyle(color: _textSecondary, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
              onPressed: _fetchAllData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
