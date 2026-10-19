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
  List<dynamic> _departments = [];

  String _searchQuery = '';
  String _selectedDeptFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
        _adminService.getDepartments().catchError((_) => <dynamic>[]),
      ]);

      if (mounted) {
        setState(() {
          _employees = results[0] as List<dynamic>;
          _payrollSummary = results[1] as Map<String, dynamic>;
          _payrollSlips = results[2] as List<dynamic>;
          _departments = results[3] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
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

  List<String> _getDepartmentNames() {
    if (_departments.isEmpty) {
      return ['ALL', 'Kitchen Operations', 'Campus Delivery', 'Engineering & Tech', 'Support & Dispute Care', 'Hygiene & Facilities', 'Executive Management'];
    }
    final names = _departments.map((d) => (d['name'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
    return ['ALL', ...names];
  }

  // ==========================================
  // 1. ADD / EDIT EMPLOYEE MODAL
  // ==========================================
  void _showAddEmployeeModal({Map<String, dynamic>? existingEmp}) {
    final bool isEditing = existingEmp != null;
    final nameCtrl = TextEditingController(text: existingEmp?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: existingEmp?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: existingEmp?['email'] ?? '');
    final expectationsCtrl = TextEditingController(text: existingEmp?['expectations'] ?? '');
    final salaryCtrl = TextEditingController(text: (existingEmp?['base_salary'] ?? '').toString());
    final roleCtrl = TextEditingController(text: existingEmp?['role'] ?? 'Staff');
    final idCtrl = TextEditingController(text: existingEmp?['national_id'] ?? '');
    final shifCtrl = TextEditingController(text: (existingEmp?['shif_deduction'] ?? '0').toString());
    final nssfCtrl = TextEditingController(text: (existingEmp?['nssf_deduction'] ?? '0').toString());
    final housingCtrl = TextEditingController(text: (existingEmp?['housing_levy'] ?? '0').toString());
    bool sendWelcomeEmail = true;

    final deptList = _getDepartmentNames().where((d) => d != 'ALL').toList();
    String selectedDept = existingEmp?['department'] ?? (deptList.isNotEmpty ? deptList.first : 'Operations');
    String selectedSalaryType = existingEmp?['salary_type'] ?? 'MONTHLY';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                    IconButton(icon: const Icon(Icons.close, color: _textSecondary), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
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
                    labelText: 'M-PESA Phone (e.g. 254712345678) *',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Staff Email (for appointment letter & app link) *',
                    labelStyle: const TextStyle(color: _neonCyan, fontSize: 12),
                    hintText: 'e.g. staff.member@university.edu',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: idCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'National ID / Passport Number',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                // Department Selector
                const Text('Department *', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: deptList.map((dept) {
                    final isSel = selectedDept == dept;
                    return ChoiceChip(
                      label: Text(dept, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: isSel,
                      selectedColor: _neonCyan,
                      backgroundColor: _surfaceLight,
                      onSelected: (val) {
                        setSheetState(() {
                          selectedDept = dept;
                          // If department has role presets, auto-suggest first role
                          final matchedDept = _departments.firstWhere((d) => d['name'] == dept, orElse: () => null);
                          if (matchedDept != null && matchedDept['roles'] is List && (matchedDept['roles'] as List).isNotEmpty) {
                            final firstRole = matchedDept['roles'][0];
                            if (roleCtrl.text.isEmpty || roleCtrl.text == 'Staff') {
                              roleCtrl.text = firstRole['title'] ?? 'Staff';
                              if (salaryCtrl.text.isEmpty || salaryCtrl.text == '0') {
                                salaryCtrl.text = (firstRole['default_salary'] ?? '').toString();
                              }
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Role Presets for chosen department
                Builder(
                  builder: (context) {
                    final matchedDept = _departments.firstWhere((d) => d['name'] == selectedDept, orElse: () => null);
                    if (matchedDept != null && matchedDept['roles'] is List && (matchedDept['roles'] as List).isNotEmpty) {
                      final roles = matchedDept['roles'] as List;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Suggested Roles for this Department:', style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: roles.map((r) {
                              final title = r['title'] ?? '';
                              final sal = (r['default_salary'] as num?)?.toDouble() ?? 0.0;
                              return ActionChip(
                                backgroundColor: _surfaceLight,
                                label: Text('$title (KES ${sal.toStringAsFixed(0)})', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                onPressed: () {
                                  setSheetState(() {
                                    roleCtrl.text = title;
                                    salaryCtrl.text = sal.toStringAsFixed(0);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: roleCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Assigned Role Title *',
                          labelStyle: const TextStyle(color: _textSecondary),
                          filled: true,
                          fillColor: _surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: salaryCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Base Salary (KES) *',
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

                // Statutory Deductions
                const Text('Kenyan Statutory Deductions (Optional):', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
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
                const SizedBox(height: 14),

                // Job Duties & Deliverables
                TextField(
                  controller: expectationsCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Expected Duties & Key Deliverables *',
                    labelStyle: const TextStyle(color: _neonCyan, fontSize: 12, fontWeight: FontWeight.bold),
                    hintText: 'e.g. Daily mess hall food distribution, kitchen POS operations, daily hygiene checks, and student assistance.',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                if (!isEditing) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _neonCyan.withOpacity(0.3)),
                    ),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Send Welcome & Appointment Email', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Sends official appointment letter with app download links to the staff member.', style: TextStyle(color: _textSecondary, fontSize: 10)),
                      value: sendWelcomeEmail,
                      activeColor: _neonCyan,
                      checkColor: Colors.black,
                      onChanged: (val) => setSheetState(() => sendWelcomeEmail = val ?? true),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                const SizedBox(height: 8),
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
                    final email = emailCtrl.text.trim();
                    final sal = double.tryParse(salaryCtrl.text.trim());
                    if (name.isEmpty || phone.isEmpty || sal == null || sal <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid name, phone, and salary'), backgroundColor: _neonRed));
                      return;
                    }
                    Navigator.pop(ctx);
                    final payload = {
                      'name': name,
                      'phone': phone,
                      'email': email.toLowerCase(),
                      'expectations': expectationsCtrl.text.trim(),
                      'send_welcome_email': sendWelcomeEmail,
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(sendWelcomeEmail && email.isNotEmpty
                                ? 'Employee registered & appointment email sent with app link!'
                                : 'Employee registered successfully!'),
                            backgroundColor: _neonCyan,
                          ),
                        );
                      }
                      _fetchAllData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed));
                    }
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Register Employee', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. DEDICATED CHANGE ROLE & SALARY MODAL
  // ==========================================
  void _showChangeCompensationModal(Map<String, dynamic> emp) {
    final empId = emp['id']?.toString() ?? '';
    final name = emp['name'] ?? 'Staff Member';
    final roleCtrl = TextEditingController(text: emp['role'] ?? 'Staff');
    final salaryCtrl = TextEditingController(text: ((emp['base_salary'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0));
    final deptList = _getDepartmentNames().where((d) => d != 'ALL').toList();
    String selectedDept = emp['department'] ?? (deptList.isNotEmpty ? deptList.first : 'Operations');
    String selectedSalaryType = emp['salary_type'] ?? 'MONTHLY';

    final shifCtrl = TextEditingController(text: ((emp['shif_deduction'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0));
    final nssfCtrl = TextEditingController(text: ((emp['nssf_deduction'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0));
    final housingCtrl = TextEditingController(text: ((emp['housing_levy'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0));

    final history = (emp['compensation_history'] as List<dynamic>?) ?? [];
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setCompState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                    Row(
                      children: [
                        const Icon(Icons.currency_exchange, color: Colors.amberAccent, size: 22),
                        const SizedBox(width: 8),
                        Text('Change Role & Salary: $name', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close, color: _textSecondary), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Update this employee’s designated department, job title, and base salary. Changes apply immediately to future payroll cycles.',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Department Selector
                const Text('Select Department *', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: deptList.map((dept) {
                    final isSel = selectedDept == dept;
                    return ChoiceChip(
                      label: Text(dept, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: isSel,
                      selectedColor: Colors.amberAccent,
                      backgroundColor: _surfaceLight,
                      onSelected: (val) {
                        setCompState(() {
                          selectedDept = dept;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Preset Roles from selected Department
                Builder(
                  builder: (context) {
                    final matchedDept = _departments.firstWhere((d) => d['name'] == selectedDept, orElse: () => null);
                    if (matchedDept != null && matchedDept['roles'] is List && (matchedDept['roles'] as List).isNotEmpty) {
                      final roles = matchedDept['roles'] as List;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quick Role Presets (Tap to Apply):', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: roles.map((r) {
                              final title = r['title'] ?? '';
                              final sal = (r['default_salary'] as num?)?.toDouble() ?? 0.0;
                              return ActionChip(
                                backgroundColor: _surfaceLight,
                                side: BorderSide(color: roleCtrl.text == title ? Colors.amberAccent : Colors.transparent),
                                label: Text('$title • KES ${sal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                onPressed: () {
                                  setCompState(() {
                                    roleCtrl.text = title;
                                    salaryCtrl.text = sal.toStringAsFixed(0);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Role and Salary Fields
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: roleCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Role / Job Title *',
                          labelStyle: const TextStyle(color: _textSecondary),
                          filled: true,
                          fillColor: _surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: salaryCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Salary (KES) *',
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

                // Deductions
                const Text('Statutory Deductions (Monthly KES):', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nssfCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'NSSF',
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
                          labelText: 'SHIF',
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

                // History accordion if exists
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Past Compensation Changes:', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: history.reversed.take(3).map((h) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            '• ${h['old_role'] ?? 'Staff'} (KES ${h['old_salary'] ?? 0}) ➔ ${h['new_role']} (KES ${h['new_salary']})',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                isSaving
                    ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final newRole = roleCtrl.text.trim();
                          final newSal = double.tryParse(salaryCtrl.text.trim()) ?? 0.0;
                          if (newRole.isEmpty || newSal <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please provide a valid role and salary > 0'), backgroundColor: _neonRed),
                            );
                            return;
                          }

                          setCompState(() => isSaving = true);
                          try {
                            final res = await _adminService.updateEmployeeCompensation(
                              employeeId: empId,
                              role: newRole,
                              department: selectedDept,
                              baseSalary: newSal,
                              salaryType: selectedSalaryType,
                              shifDeduction: double.tryParse(shifCtrl.text.trim()),
                              nssfDeduction: double.tryParse(nssfCtrl.text.trim()),
                              housingLevy: double.tryParse(housingCtrl.text.trim()),
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(res['message'] ?? 'Role & compensation updated!'), backgroundColor: _neonCyan),
                              );
                              _fetchAllData();
                            }
                          } catch (e) {
                            setCompState(() => isSaving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update Failed: $e'), backgroundColor: _neonRed));
                            }
                          }
                        },
                        child: const Text('Save & Apply New Salary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. CREATE / EDIT DEPARTMENT MODAL
  // ==========================================
  void _showCreateDepartmentModal({Map<String, dynamic>? existingDept}) {
    final bool isEditing = existingDept != null;
    final deptId = existingDept?['id']?.toString() ?? '';
    final nameCtrl = TextEditingController(text: existingDept?['name'] ?? '');
    final codeCtrl = TextEditingController(text: existingDept?['code'] ?? '');
    final descCtrl = TextEditingController(text: existingDept?['description'] ?? '');
    final budgetCtrl = TextEditingController(text: ((existingDept?['budget'] as num?)?.toDouble() ?? 100000.0).toStringAsFixed(0));

    final List<Map<String, dynamic>> rolesList = [];
    if (existingDept != null && existingDept['roles'] is List) {
      for (var r in (existingDept['roles'] as List)) {
        rolesList.add({'title': r['title'] ?? '', 'default_salary': (r['default_salary'] as num?)?.toDouble() ?? 0.0});
      }
    } else {
      rolesList.addAll([
        {'title': 'Supervisor', 'default_salary': 40000.0},
        {'title': 'Specialist', 'default_salary': 25000.0},
      ]);
    }

    final newRoleTitleCtrl = TextEditingController();
    final newRoleSalCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDeptState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                    Row(
                      children: [
                        const Icon(Icons.apartment, color: _neonCyan, size: 22),
                        const SizedBox(width: 8),
                        Text(isEditing ? 'Edit Department' : 'Create New Department', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close, color: _textSecondary), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Define organizational departments, monthly expenditure budgets, and role compensation presets.',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Department Name (e.g. Campus Security) *',
                          labelStyle: const TextStyle(color: _textSecondary),
                          filled: true,
                          fillColor: _surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: codeCtrl,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Code',
                          labelStyle: const TextStyle(color: _textSecondary),
                          filled: true,
                          fillColor: _surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Description / Purpose',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: budgetCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Monthly Budget Limit (KES)',
                    labelStyle: const TextStyle(color: _textSecondary),
                    filled: true,
                    fillColor: _surfaceLight,
                    prefixIcon: const Icon(Icons.account_balance_wallet, color: _neonCyan),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // Configured Roles list
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Designated Role Presets & Standard Pay:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('${rolesList.length} Roles', style: const TextStyle(color: _neonCyan, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      ...rolesList.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final r = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.badge_outlined, color: _neonCyan, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('${r['title']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              Text('KES ${(r['default_salary'] as num).toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: _neonRed, size: 16),
                                onPressed: () {
                                  setDeptState(() {
                                    rolesList.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(color: Colors.white12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: newRoleTitleCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: 'Role Title (e.g. Lead)',
                                hintStyle: TextStyle(color: _textSecondary, fontSize: 11),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: newRoleSalCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: 'Pay (KES)',
                                hintStyle: TextStyle(color: _textSecondary, fontSize: 11),
                                isDense: true,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              final title = newRoleTitleCtrl.text.trim();
                              final sal = double.tryParse(newRoleSalCtrl.text.trim()) ?? 0.0;
                              if (title.isNotEmpty && sal > 0) {
                                setDeptState(() {
                                  rolesList.add({'title': title, 'default_salary': sal});
                                  newRoleTitleCtrl.clear();
                                  newRoleSalCtrl.clear();
                                });
                              }
                            },
                            child: const Text('+ Add', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                isSaving
                    ? const Center(child: CircularProgressIndicator(color: _neonCyan))
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _neonCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department name is required'), backgroundColor: _neonRed));
                            return;
                          }

                          setDeptState(() => isSaving = true);
                          final payload = {
                            'name': name,
                            'code': codeCtrl.text.trim().isEmpty ? name.substring(0, name.length > 5 ? 5 : name.length).toUpperCase() : codeCtrl.text.trim().toUpperCase(),
                            'description': descCtrl.text.trim(),
                            'budget': double.tryParse(budgetCtrl.text.trim()) ?? 0.0,
                            'roles': rolesList,
                          };

                          try {
                            if (isEditing) {
                              await _adminService.updateDepartment(deptId, payload);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department updated!'), backgroundColor: _neonCyan));
                            } else {
                              await _adminService.createDepartment(
                                name: payload['name'] as String,
                                code: payload['code'] as String,
                                description: payload['description'] as String,
                                budget: payload['budget'] as double,
                                roles: rolesList,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department created successfully!'), backgroundColor: _neonCyan));
                            }
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              _fetchAllData();
                            }
                          } catch (e) {
                            setDeptState(() => isSaving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _neonRed));
                            }
                          }
                        },
                        child: Text(isEditing ? 'Save Department Changes' : 'Create Department', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 4. DISBURSE SALARY B2C MODAL
  // ==========================================
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
        builder: (context, setModalState) {
          final bonus = double.tryParse(bonusCtrl.text) ?? 0.0;
          final adv = double.tryParse(advanceCtrl.text) ?? 0.0;
          final net = (baseSalary + bonus) - (fixedDeductions + adv);

          return AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _neonCyan, width: 2)),
            title: Row(
              children: [
                const Icon(Icons.send_rounded, color: _neonCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Disburse Salary: ${emp['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Destination Phone: ${emp['phone']}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                  Text('Role & Dept: ${emp['role']} • ${emp['department']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const Divider(color: _surfaceLight, height: 20),
                  _buildPayRow('Base Salary', 'KES ${baseSalary.toStringAsFixed(2)}', Colors.white),
                  if (nssf > 0) _buildPayRow('NSSF Deduction', '- KES ${nssf.toStringAsFixed(2)}', _neonOrange),
                  if (shif > 0) _buildPayRow('SHIF Deduction', '- KES ${shif.toStringAsFixed(2)}', _neonOrange),
                  if (housing > 0) _buildPayRow('Housing Levy', '- KES ${housing.toStringAsFixed(2)}', _neonOrange),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bonusCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Bonus (KES)',
                      labelStyle: const TextStyle(color: _textSecondary),
                      filled: true,
                      fillColor: _surfaceLight,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: advanceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Advance Deduction (KES)',
                      labelStyle: const TextStyle(color: _textSecondary),
                      filled: true,
                      fillColor: _surfaceLight,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const Divider(color: _surfaceLight, height: 24),
                  _buildPayRow('Net Payout (Daraja B2C)', 'KES ${net.toStringAsFixed(2)}', _neonCyan, isBold: true),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final res = await _adminService.disburseSalaryB2C(
                      employeeId: emp['id'],
                      bonus: bonus,
                      advanceDeduction: adv,
                      notes: notesCtrl.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res['message'] ?? 'Salary queued to Safaricom B2C!'), backgroundColor: _neonCyan),
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
                child: const Text('Confirm & Pay (B2C)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // 5. BULK DEPARTMENTAL DISBURSEMENT MODAL
  // ==========================================
  void _showBulkDisburseModal() {
    final deptList = _getDepartmentNames();
    String selectedDept = 'ALL';

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
                children: deptList.map((dept) {
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
        title: const Text('Staff & Payroll Command', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.badge), text: 'Staff Directory'),
            Tab(icon: Icon(Icons.apartment), text: 'Departments & Roles'),
            Tab(icon: Icon(Icons.payments), text: 'Payroll Engine'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Payslip History'),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingAction(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neonCyan))
          : _errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStaffDirectoryTab(),
                    _buildDepartmentsTab(),
                    _buildPayrollEngineTab(),
                    _buildPayslipsTab(),
                  ],
                ),
    );
  }

  Widget? _buildFloatingAction() {
    if (_tabController.index == 0) {
      return FloatingActionButton.extended(
        backgroundColor: _neonCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEmployeeModal(),
      );
    } else if (_tabController.index == 1) {
      return FloatingActionButton.extended(
        backgroundColor: _neonCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_business),
        label: const Text('Create Department', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showCreateDepartmentModal(),
      );
    }
    return null;
  }

  // ==========================================
  // TAB 1: STAFF DIRECTORY
  // ==========================================
  Widget _buildStaffDirectoryTab() {
    final deptNames = _getDepartmentNames();

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
                  children: deptNames.map((dept) {
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
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _showAddEmployeeModal(),
                        child: const Text('+ Register Employee', style: TextStyle(color: _neonCyan)),
                      ),
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
                          Builder(
                            builder: (context) {
                              final email = emp['email']?.toString() ?? '';
                              final duties = emp['expectations']?.toString() ?? '';
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (email.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.email_outlined, color: _neonCyan, size: 12),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            email,
                                            style: const TextStyle(color: _textSecondary, fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (duties.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Duties: $duties',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              Builder(
                                builder: (ctx) {
                                  final empEmail = emp['email']?.toString() ?? '';
                                  if (empEmail.isEmpty) return const SizedBox.shrink();
                                  return OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _neonCyan,
                                      side: BorderSide(color: _neonCyan.withOpacity(0.5)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    onPressed: () async {
                                      try {
                                        final res = await _adminService.resendStaffWelcomeEmail(emp['id']);
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(res['message'] ?? 'Appointment letter resent!'), backgroundColor: _neonCyan),
                                          );
                                        }
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to resend: $e'), backgroundColor: _neonRed),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.mark_email_read_outlined, size: 14),
                                    label: const Text('Resend Email', style: TextStyle(fontSize: 11)),
                                  );
                                },
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amberAccent,
                                  side: const BorderSide(color: Colors.amberAccent),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: () => _showChangeCompensationModal(emp),
                                icon: const Icon(Icons.currency_exchange, size: 14),
                                label: const Text('Change Role & Salary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: _surfaceLight),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: () => _showAddEmployeeModal(existingEmp: emp),
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('Edit', style: TextStyle(fontSize: 12)),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _neonCyan,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
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

  // ==========================================
  // TAB 2: DEPARTMENTS & ROLES MANAGER
  // ==========================================
  Widget _buildDepartmentsTab() {
    double totalBudget = 0.0;
    double totalActualPayroll = 0.0;
    int totalAssigned = 0;

    for (var d in _departments) {
      totalBudget += (d['budget'] as num?)?.toDouble() ?? 0.0;
      totalActualPayroll += (d['monthly_payroll'] as num?)?.toDouble() ?? 0.0;
      totalAssigned += (d['active_employees'] as num?)?.toInt() ?? 0;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF131A2A), Color(0xFF1E283E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _neonCyan.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Company Organizational Structure', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text('${_departments.length} DEPARTMENTS', style: const TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Departmental Budget', style: TextStyle(color: _textSecondary, fontSize: 11)),
                      Text('KES ${totalBudget.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Committed Payroll', style: TextStyle(color: _textSecondary, fontSize: 11)),
                      Text('KES ${totalActualPayroll.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.groups, color: _neonBlue, size: 16),
                  const SizedBox(width: 6),
                  Text('$totalAssigned Staff assigned across departments', style: const TextStyle(color: _neonBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Configured Departments & Role Pay', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.add_circle, color: _neonCyan, size: 16),
              label: const Text('Add Department', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold)),
              onPressed: () => _showCreateDepartmentModal(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_departments.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Icon(Icons.apartment_outlined, color: _textSecondary, size: 48),
                  const SizedBox(height: 12),
                  const Text('No departments configured.', style: TextStyle(color: _textSecondary)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _neonCyan, foregroundColor: Colors.black),
                    onPressed: () => _showCreateDepartmentModal(),
                    child: const Text('Create First Department'),
                  ),
                ],
              ),
            ),
          )
        else
          ..._departments.map((d) {
            final deptMap = d as Map<String, dynamic>;
            final name = deptMap['name'] ?? 'Department';
            final code = deptMap['code'] ?? 'GEN';
            final desc = deptMap['description'] ?? '';
            final budget = (deptMap['budget'] as num?)?.toDouble() ?? 0.0;
            final payroll = (deptMap['monthly_payroll'] as num?)?.toDouble() ?? 0.0;
            final empCount = (deptMap['active_employees'] as num?)?.toInt() ?? 0;
            final roles = (deptMap['roles'] as List<dynamic>?) ?? [];

            final isOverBudget = budget > 0 && payroll > budget;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isOverBudget ? _neonRed.withOpacity(0.5) : _surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _neonCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text(code, style: const TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                            tooltip: 'Edit Department',
                            onPressed: () => _showCreateDepartmentModal(existingDept: deptMap),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: _neonRed, size: 18),
                            tooltip: 'Delete Department',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: _cardColor,
                                  title: Text('Delete $name?', style: const TextStyle(color: Colors.white)),
                                  content: const Text('Are you sure you want to remove this department?', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: _neonRed),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await _adminService.deleteDepartment(deptMap['id']);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department deleted'), backgroundColor: _neonCyan));
                                  _fetchAllData();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete Failed: $e'), backgroundColor: _neonRed));
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$empCount Staff Allocated', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(
                        'Payroll: KES ${payroll.toStringAsFixed(0)} / ${budget > 0 ? "KES ${budget.toStringAsFixed(0)}" : "No Limit"}',
                        style: TextStyle(color: isOverBudget ? _neonRed : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Preset Roles Chip Deck
                  if (roles.isNotEmpty) ...[
                    const Text('Configured Roles & Pay:', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: roles.map((r) {
                        final title = r['title'] ?? 'Role';
                        final sal = (r['default_salary'] as num?)?.toDouble() ?? 0.0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _surfaceLight, borderRadius: BorderRadius.circular(8)),
                          child: Text('$title: KES ${sal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================
  // TAB 3: PAYROLL ENGINE
  // ==========================================
  Widget _buildPayrollEngineTab() {
    final activeCount = _payrollSummary['active_employees'] ?? 0;
    final liability = (_payrollSummary['monthly_liability'] as num?)?.toDouble() ?? 0.0;
    final paidThisMonth = (_payrollSummary['paid_this_month'] as num?)?.toDouble() ?? 0.0;
    final pending = (_payrollSummary['pending_payout'] as num?)?.toDouble() ?? 0.0;
    final cycle = _payrollSummary['current_cycle'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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

  // ==========================================
  // TAB 4: PAYSLIP HISTORY
  // ==========================================
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
