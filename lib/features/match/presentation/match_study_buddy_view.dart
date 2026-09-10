import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'match_library_lockin_view.dart'; // For Shared Pomodoro Link

class MatchStudyBuddyView extends StatefulWidget {
  final Map<String, dynamic>? userModel;
  
  const MatchStudyBuddyView({super.key, this.userModel});

  @override
  State<MatchStudyBuddyView> createState() => _MatchStudyBuddyViewState();
}

class _MatchStudyBuddyViewState extends State<MatchStudyBuddyView> with SingleTickerProviderStateMixin {
  bool _isAcademicMode = false;
  bool _isToggling = false;
  
  List<Map<String, dynamic>> _allBuddies = [];
  List<Map<String, dynamic>> _filteredBuddies = [];
  
  String _searchQuery = '';
  late TabController _tabController;

  // Study profile fields
  String _myStatus = 'Available';
  String _myGoal = 'Pass upcoming exams';
  String _strongIn = '';
  String _needsHelp = '';
  bool _isTutor = false;
  int _studyStreak = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkInitialState();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialState() async {
    final String uid = widget.userModel?['uid'] ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    if (uid == 'guest') return;
    
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _isAcademicMode = data['isAcademicMode'] == true;
        _myStatus = data['study_status'] ?? 'Available';
        _myGoal = data['study_goal'] ?? 'Pass upcoming exams';
        _strongIn = data['study_strong_in'] ?? '';
        _needsHelp = data['study_needs_help'] ?? '';
        _isTutor = data['isTutor'] == true;
        _studyStreak = data['studyStreak'] ?? 0;
      });
      
      if (_isAcademicMode) {
        _fetchBuddies();
      }
    }
  }

  Future<void> _fetchBuddies() async {
    final String uid = widget.userModel?['uid'] ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isAcademicMode', isEqualTo: true)
          .limit(20)
          .get();
      
      final List<Map<String, dynamic>> list = [];
      for (var doc in snapshot.docs) {
        if (doc.id != uid) {
          final data = doc.data();
          list.add({
            'uid': doc.id,
            'name': data['displayName'] ?? data['firstName'] ?? data['username'] ?? 'Anonymous',
            'units': data['study_units'] ?? 'General Studies',
            'status': data['study_status'] ?? 'Available',
            'goal': data['study_goal'] ?? 'Pass exams',
            'strongIn': data['study_strong_in'] ?? 'Not specified',
            'needsHelp': data['study_needs_help'] ?? 'Not specified',
            'avatarUrl': data['profileImageUrl'] ?? '',
            'isTutor': data['isTutor'] == true,
            'endorsements': data['skillEndorsements'] ?? 0,
            'studyStreak': data['studyStreak'] ?? 0,
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _allBuddies = list;
          _filterBuddies();
        });
      }
    } catch (e) {
      debugPrint('Error fetching buddies: $e');
    }
  }

  void _filterBuddies() {
    if (_searchQuery.isEmpty) {
      _filteredBuddies = List.from(_allBuddies);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredBuddies = _allBuddies.where((b) {
        final name = b['name'].toString().toLowerCase();
        final units = b['units'].toString().toLowerCase();
        final strongIn = b['strongIn'].toString().toLowerCase();
        return name.contains(q) || units.contains(q) || strongIn.contains(q);
      }).toList();
    }
  }

  Future<void> _updateStudyProfile() async {
    final String uid = widget.userModel?['uid'] ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    if (uid == 'guest') return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'study_status': _myStatus,
      'study_goal': _myGoal,
      'study_strong_in': _strongIn,
      'study_needs_help': _needsHelp,
      'isTutor': _isTutor,
    });
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Study profile updated!')));
  }

  Future<void> _toggleAcademicMode(bool value) async {
    setState(() => _isToggling = true);
    final String uid = widget.userModel?['uid'] ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    if (uid == 'guest') {
      setState(() => _isToggling = false);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'isAcademicMode': value});
      if (mounted) {
        setState(() { _isAcademicMode = value; _isToggling = false; });
        if (value) {
          _fetchBuddies();
        } else {
          setState(() { _allBuddies = []; _filteredBuddies = []; });
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value ? 'Academic Mode Activated! 📚' : 'Academic Mode Deactivated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isToggling = false);
      }
    }
  }

  int _calculateMatchPercentage(String myNeeds, String theirStrongIn) {
    if (myNeeds.isEmpty || theirStrongIn.isEmpty) return math.Random().nextInt(40) + 40;
    final myNeedsList = myNeeds.toLowerCase().split(',').map((e) => e.trim());
    final theirStrongInList = theirStrongIn.toLowerCase().split(',').map((e) => e.trim());
    
    int matchCount = 0;
    for (var need in myNeedsList) {
      if (theirStrongInList.any((strong) => strong.contains(need) || need.contains(strong))) {
        matchCount++;
      }
    }
    
    if (matchCount > 0) return 90 + math.Random().nextInt(10); // High match
    return 50 + math.Random().nextInt(30);
  }

  void _showInviteSheet(Map<String, dynamic> buddy) {
    final TextEditingController locationController = TextEditingController(text: 'Library');
    final TextEditingController notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isVirtual = false;
    bool isGroup = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite ${buddy['name']} to Study', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    // Quick Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(label: const Text('In 1hr'), onPressed: () => setSheetState(() => selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))))),
                          const SizedBox(width: 8),
                          ActionChip(label: const Text('Tonight'), onPressed: () => setSheetState(() => selectedTime = const TimeOfDay(hour: 20, minute: 0))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        const Text('Type:', style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 16),
                        ChoiceChip(label: const Text('Physical'), selected: !isVirtual, onSelected: (v) => setSheetState(() => isVirtual = false), selectedColor: Colors.blueAccent),
                        const SizedBox(width: 8),
                        ChoiceChip(label: const Text('Virtual Room'), selected: isVirtual, onSelected: (v) => setSheetState(() => isVirtual = true), selectedColor: Colors.blueAccent),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (!isVirtual)
                      TextField(controller: locationController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Location', labelStyle: TextStyle(color: Colors.white54), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
                    
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton.icon(onPressed: () async {
                          final date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                          if (date != null) setSheetState(() => selectedDate = date);
                        }, icon: const Icon(Icons.calendar_today, size: 16, color: Colors.blueAccent), label: Text(DateFormat('MMM dd').format(selectedDate), style: const TextStyle(color: Colors.white)))),
                        const SizedBox(width: 16),
                        Expanded(child: OutlinedButton.icon(onPressed: () async {
                          final time = await showTimePicker(context: context, initialTime: selectedTime);
                          if (time != null) setSheetState(() => selectedTime = time);
                        }, icon: const Icon(Icons.access_time, size: 16, color: Colors.blueAccent), label: Text(selectedTime.format(context), style: const TextStyle(color: Colors.white)))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(controller: notesController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Notes Link (Google Drive / Notion)', labelStyle: TextStyle(color: Colors.white54))),
                    
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(value: isGroup, onChanged: (v) => setSheetState(() => isGroup = v ?? false), fillColor: MaterialStateProperty.all(Colors.blueAccent)),
                        const Text('Make this a Group Study', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () async {
                          final myUid = widget.userModel?['uid'] ?? FirebaseAuth.instance.currentUser?.uid;
                          final myName = widget.userModel?['displayName'] ?? widget.userModel?['firstName'] ?? 'Anonymous';
                          
                          final sessionDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
  
                          await FirebaseFirestore.instance.collection('study_sessions').add({
                            'senderId': myUid,
                            'senderName': myName,
                            'receiverId': isGroup ? 'group_board' : buddy['uid'],
                            'receiverName': isGroup ? 'Group' : buddy['name'],
                            'timestamp': sessionDateTime,
                            'isVirtual': isVirtual,
                            'location': isVirtual ? 'https://meet.jit.si/DISHI_${myUid}_${math.Random().nextInt(9999)}' : locationController.text,
                            'isGroup': isGroup,
                            'notesLink': notesController.text,
                            'status': 'pending',
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Study Invite Sent!')));
                          }
                        },
                        child: const Text('Send Invite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _showProfileSettingsSheet() {
    final TextEditingController goalController = TextEditingController(text: _myGoal);
    final TextEditingController strongController = TextEditingController(text: _strongIn);
    final TextEditingController needsController = TextEditingController(text: _needsHelp);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Study Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  const Text('Current Status', style: TextStyle(color: Colors.white70)),
                  DropdownButton<String>(
                    value: _myStatus,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white),
                    items: ['Available', 'In Class', 'Cramming for Exams', 'Do Not Disturb'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) { if (v != null) setSheetState(() => _myStatus = v); },
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(controller: goalController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Current Study Goal', labelStyle: TextStyle(color: Colors.white54))),
                  const SizedBox(height: 16),
                  TextField(controller: strongController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Strong In (Skills)', labelStyle: TextStyle(color: Colors.white54), hintText: 'e.g. Python, Calculus')),
                  const SizedBox(height: 16),
                  TextField(controller: needsController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Needs Help With', labelStyle: TextStyle(color: Colors.white54), hintText: 'e.g. Accounting, Physics')),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('Tutor Mode', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('I am offering to tutor others', style: TextStyle(color: Colors.white54)),
                    activeColor: Colors.blueAccent,
                    value: _isTutor,
                    onChanged: (v) => setSheetState(() => _isTutor = v),
                  ),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      onPressed: () {
                        setState(() {
                          _myGoal = goalController.text;
                          _strongIn = strongController.text;
                          _needsHelp = needsController.text;
                        });
                        _updateStudyProfile();
                        Navigator.pop(context);
                      },
                      child: const Text('Save Profile', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _endorseSkill(String buddyId, String buddyName) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You endorsed $buddyName!')));
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = _isAcademicMode ? const Color(0xFF0F172A) : const Color(0xFF0C101B);
    final Color cardColor = _isAcademicMode ? const Color(0xFF1E293B) : const Color(0xFF131A2A);
    final Color accentColor = _isAcademicMode ? Colors.blueAccent : const Color(0xFF9C27B0);
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Study Buddies', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isAcademicMode)
            IconButton(icon: const Icon(Icons.settings, color: Colors.blueAccent), onPressed: _showProfileSettingsSheet)
        ],
        bottom: _isAcademicMode ? TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Find', icon: Icon(Icons.search)),
            Tab(text: 'Groups', icon: Icon(Icons.groups)),
            Tab(text: 'Invites', icon: Icon(Icons.inbox)),
          ],
        ) : null,
      ),
      body: !_isAcademicMode 
          ? _buildDisabledState(cardColor, accentColor)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFindBuddiesTab(cardColor, accentColor),
                _buildGroupStudyTab(cardColor),
                _buildInvitesTab(cardColor),
              ],
            ),
    );
  }

  Widget _buildDisabledState(Color cardColor, Color accentColor) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: accentColor.withOpacity(0.5))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Academic Mode', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  const Text('Turn on to find study partners.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              _isToggling ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()) : Switch(value: _isAcademicMode, activeColor: accentColor, onChanged: _toggleAcademicMode)
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFindBuddiesTab(Color cardColor, Color accentColor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: accentColor.withOpacity(0.5))),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Academic Mode', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Status: $_myStatus', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    _isToggling ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()) : Switch(value: _isAcademicMode, activeColor: accentColor, onChanged: _toggleAcademicMode)
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text('Study Streak: $_studyStreak days', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            onChanged: (val) { setState(() { _searchQuery = val; _filterBuddies(); }); },
            decoration: InputDecoration(
              hintText: 'Search by Unit Code or Skill...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Expanded(
          child: _filteredBuddies.isEmpty
              ? const Center(child: Text('No study buddies found.', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredBuddies.length,
                  itemBuilder: (context, index) {
                    return _buildBuddyCard(_filteredBuddies[index], cardColor, accentColor);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBuddyCard(Map<String, dynamic> b, Color cardColor, Color accentColor) {
    final avatarUrl = b['avatarUrl'] as String;
    final int matchPct = _calculateMatchPercentage(_needsHelp, b['strongIn']);
    final bool isTutor = b['isTutor'] == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: Colors.black26, backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null, child: avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(b['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          if (isTutor) ...[
                            const SizedBox(width: 4),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: const Text('TUTOR', style: TextStyle(color: Colors.purpleAccent, fontSize: 8, fontWeight: FontWeight.bold))),
                          ]
                        ],
                      ),
                      Text(b['units'], style: TextStyle(color: accentColor, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: matchPct >= 80 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text('$matchPct% Match', style: TextStyle(color: matchPct >= 80 ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showInviteSheet(b),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(20)), child: const Text('INVITE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
                  )
                ],
              )
            ],
          ),
          if (b['status'] == 'In Class') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [Icon(Icons.do_not_disturb_on, color: Colors.redAccent, size: 14), SizedBox(width: 4), Text('Currently in Class', style: TextStyle(color: Colors.redAccent, fontSize: 12))]),
            )
          ],
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Strong In:', style: TextStyle(color: Colors.white54, fontSize: 10)),
                Row(
                  children: [
                    Text(b['strongIn'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.thumb_up, color: Colors.white54, size: 12), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _endorseSkill(b['uid'], b['name']))
                  ],
                ),
              ])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Needs Help:', style: TextStyle(color: Colors.white54, fontSize: 10)),
                Text(b['needsHelp'], style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ])),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildGroupStudyTab(Color cardColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('study_sessions').where('isGroup', isEqualTo: true).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No active group sessions.', style: TextStyle(color: Colors.white54)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final date = (data['timestamp'] as Timestamp).toDate();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('👥 Group Study', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                      Text('${DateFormat('MMM dd • h:mm a').format(date)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Host: ${data['senderName']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [Icon(data['isVirtual'] ? Icons.computer : Icons.location_on, color: Colors.blueAccent, size: 14), const SizedBox(width: 4), Expanded(child: Text(data['location'], style: const TextStyle(color: Colors.blueAccent)))]),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined Group Session!')));
                  }, style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent), child: const Text('Join Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInvitesTab(Color cardColor) {
    final myUid = widget.userModel?['uid'] ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('study_sessions').where('receiverId', isEqualTo: myUid).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No study invites yet.', style: TextStyle(color: Colors.white54)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            
            final date = (data['timestamp'] as Timestamp).toDate();
            final isVirtual = data['isVirtual'] == true;
            final status = data['status'] as String;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: status == 'pending' ? Colors.blueAccent : Colors.transparent)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Invite from ${data['senderName']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(status.toUpperCase(), style: TextStyle(color: status == 'accepted' ? Colors.greenAccent : (status == 'declined' ? Colors.redAccent : Colors.orangeAccent), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${DateFormat('MMM dd, yyyy • h:mm a').format(date)}', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(isVirtual ? Icons.computer : Icons.location_on, color: Colors.blueAccent, size: 14),
                      const SizedBox(width: 4),
                      Expanded(child: Text(data['location'], style: const TextStyle(color: Colors.blueAccent))),
                    ],
                  ),
                  if (data['notesLink'] != null && data['notesLink'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [const Icon(Icons.link, color: Colors.white54, size: 14), const SizedBox(width: 4), Expanded(child: Text(data['notesLink'], style: const TextStyle(color: Colors.white54, decoration: TextDecoration.underline)))]),
                  ],
                  if (data['isGroup'] == true) ...[
                    const SizedBox(height: 4),
                    const Text('👥 Group Study Session', style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                  
                  if (status == 'pending') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: () => FirebaseFirestore.instance.collection('study_sessions').doc(docId).update({'status': 'declined'}), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)), child: const Text('Decline', style: TextStyle(color: Colors.redAccent)))),
                        const SizedBox(width: 16),
                        Expanded(child: ElevatedButton(onPressed: () => FirebaseFirestore.instance.collection('study_sessions').doc(docId).update({'status': 'accepted'}), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent), child: const Text('Accept', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
                      ],
                    )
                  ],
                  if (status == 'accepted') ...[
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchLibraryLockInView())),
                      icon: const Icon(Icons.timer, color: Colors.orangeAccent),
                      label: const Text('Start Shared Pomodoro', style: TextStyle(color: Colors.orangeAccent)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orangeAccent)),
                    ))
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }
}
