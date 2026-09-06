import 'package:flutter/material.dart';
import '../../../core/theme/mpesa_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/presentation/login_view.dart';

// -- CUSTOM DESIGN COLORS --
const Color _bgColor = Color(0xFF0C101B);
const Color _cardColor = Color(0xFF131A2A);
const Color _surfaceLight = Color(0xFF1A2235);
const Color _textSecondary = Color(0xFF8B9BB4);
const Color _neonCyan = Color(0xFF05D5AA);
const Color _neonOrange = Color(0xFFFF6F00);
const Color _neonPink = Color(0xFFF92B60);

class FundiDashboardView extends StatefulWidget {
  final Map<String, dynamic> user;

  const FundiDashboardView({super.key, required this.user});

  @override
  State<FundiDashboardView> createState() => _FundiDashboardViewState();
}

class _FundiDashboardViewState extends State<FundiDashboardView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  double _totalEarnings = 0.0;
  List<dynamic> _openRequests = [];
  List<dynamic> _inProgress = [];
  List<dynamic> _completed = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchJobs();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    // Mocked data for Fundi Jobs
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _openRequests = [
        {
          'id': 'job1',
          'title': 'Math Tutoring (Calculus)',
          'payer_name': 'James O.',
          'phone': '254711223344',
          'amount': 500.0,
          'status': 'Open',
        }
      ];
      
      _inProgress = [
        {
          'id': 'job2',
          'title': 'Fix Laptop OS',
          'payer_name': 'Grace W.',
          'phone': '254799887766',
          'amount': 1500.0,
          'status': 'In Escrow',
        }
      ];
      
      _completed = [
        {
          'id': 'job3',
          'title': 'Sneaker Wash (3 pairs)',
          'payer_name': 'Peter M.',
          'phone': '254700112233',
          'amount': 900.0,
          'status': 'Completed',
          'net_amount': 886.5
        }
      ];
      
      _totalEarnings = _completed.fold(0.0, (sum, item) => sum + (item['net_amount'] ?? 0.0));
      _isLoading = false;
    });
  }

  Future<void> _launchWhatsApp(String phone) async {
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
      }
    }
  }

  void _acceptJob(String jobId) {
    setState(() {
      final job = _openRequests.firstWhere((j) => j['id'] == jobId);
      _openRequests.remove(job);
      job['status'] = 'In Progress (Waiting for Escrow)';
      _inProgress.add(job);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Job accepted! Await escrow deposit before starting work.'))
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  void _showProfileMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: MPesaTheme.primaryGreen, width: 2)),
        title: const Text('Profile Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: MPesaTheme.primaryGreen),
              title: const Text('My Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile coming soon')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: _neonPink),
              title: const Text('Logout', style: TextStyle(color: _neonPink)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView()));
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: MPesaTheme.primaryGreen))),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar() {
    if (_isSearching) {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => setState(() {
              _isSearching = false;
              _searchQuery = '';
            }),
          ),
          Expanded(
            child: TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: _textSecondary),
                border: InputBorder.none,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ],
      );
    }

    final fundiName = widget.user['name'] ?? widget.user['displayName'] ?? 'Fundi';
    final profileImageUrl = widget.user['profileImageUrl'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B29).withOpacity(0.8),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => _showProfileMenu(context),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : const AssetImage('assets/img/dishi_logo.png') as ImageProvider,
                  backgroundColor: _surfaceLight,
                  child: profileImageUrl == null ? const Icon(Icons.handyman, color: _textSecondary, size: 20) : null,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bgColor, width: 2),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_getGreeting(), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  fundiName, 
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isSearching = true),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.search, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen))
          : NestedScrollView(
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  SliverAppBar(
                    expandedHeight: 80,
                    floating: true,
                    pinned: true,
                    backgroundColor: _bgColor,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                        child: _buildCustomAppBar(),
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(60),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: MPesaTheme.primaryGreen,
                          labelColor: MPesaTheme.primaryGreen,
                          unselectedLabelColor: Colors.white54,
                          isScrollable: true,
                          tabs: const [
                            Tab(text: 'Open Requests'),
                            Tab(text: 'In Progress'),
                            Tab(text: 'History'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: Column(
                children: [
                  // Earnings Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [MPesaTheme.primaryGreen.withOpacity(0.8), MPesaTheme.primaryGreen.withOpacity(0.4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                          child: const Icon(Icons.account_balance_wallet, color: Colors.black, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Earnings', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                              Text('KES $_totalEarnings', style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Tabs Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildJobList(_openRequests, true),
                        _buildJobList(_inProgress, false),
                        _buildJobList(_completed, false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildJobList(List<dynamic> jobs, bool isOpenRequest) {
    if (jobs.isEmpty) {
      return const Center(child: Text('No jobs here.', style: TextStyle(color: Colors.white54)));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(job['title'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                  Text('KES ${job['amount']}', style: const TextStyle(color: MPesaTheme.primaryGreen, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(radius: 12, backgroundColor: Colors.white12, child: Icon(Icons.person, size: 12, color: Colors.white)),
                      const SizedBox(width: 8),
                      Text(job['payer_name'], style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  if (!isOpenRequest)
                    IconButton(
                      icon: const Icon(Icons.wechat, color: Color(0xFF25D366)),
                      onPressed: () => _launchWhatsApp(job['phone']),
                      tooltip: 'Chat on WhatsApp',
                    )
                ],
              ),
              const SizedBox(height: 12),
              if (isOpenRequest)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
                    onPressed: () => _acceptJob(job['id']),
                    child: const Text('Accept Job', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                  child: Text(job['status'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                )
            ],
          ),
        );
      },
    );
  }
}
