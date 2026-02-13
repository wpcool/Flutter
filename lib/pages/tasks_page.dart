import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/user.dart';
import 'create_record_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _apiService = ApiService();
  final _storage = StorageService();
  List<dynamic> _tasks = [];
  bool _isLoading = true;
  User? _userInfo;
  String _today = '';
  
  // 统计数据
  int _todayCount = 0;
  int _completedCount = 0;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _today = DateFormat('MM月dd日').format(DateTime.now());
    _userInfo = _storage.getUserInfo();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await _apiService.get('/api/tasks?date=$today');
      
      if (response is List) {
        setState(() => _tasks = response);
        _calculateStats();
      }
    } catch (e) {
      print('加载任务失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    int completed = 0;
    int pending = 0;
    
    for (final task in _tasks) {
      final items = task['items'] as List? ?? [];
      for (final item in items) {
        final count = item['record_count'] ?? 0;
        if (count > 0) {
          completed++;
        } else {
          pending++;
        }
      }
    }
    
    setState(() {
      _todayCount = _tasks.length;
      _completedCount = completed;
      _pendingCount = pending;
    });
  }

  Future<void> _loadTaskCompletion(dynamic task) async {
    final userInfo = _storage.getUserInfo();
    if (userInfo == null) return;
    
    try {
      final res = await _apiService.get('/api/tasks/${task['id']}/completion/${userInfo.id}');
      if (res['items'] != null) {
        final itemCountMap = <int, int>{};
        for (final i in res['items']) {
          itemCountMap[i['item_id']] = i['count'] ?? 0;
        }
        
        // 更新任务中的商品记录数
        final updatedItems = (task['items'] as List?)?.map((item) {
          final count = itemCountMap[item['id']] ?? 0;
          return {
            ...item,
            'record_count': count,
          };
        }).toList();
        
        setState(() {
          task['items'] = updatedItems;
          task['total_records'] = res['total_records'] ?? 0;
        });
        
        _calculateStats();
      }
    } catch (e) {
      print('加载完成状态失败: $e');
    }
  }

  void _onStartSurvey(dynamic task) async {
    // 先加载完成状态
    await _loadTaskCompletion(task);
    
    // 保存选中的任务
    await _storage.setSelectedTask(task);
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateRecordPage(
            taskId: task['id'],
            taskTitle: task['title'] ?? '',
          ),
        ),
      );
    }
  }

  bool get _hasTask => _tasks.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTasks,
          color: const Color(0xFF6366F1),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 欢迎卡片
                _buildWelcomeCard(),
                const SizedBox(height: 16),
                // 统计网格
                _buildStatsGrid(),
                const SizedBox(height: 16),
                // 任务区域
                _buildTaskSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 欢迎卡片
  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('👋', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '欢迎, ${_userInfo?.nickname ?? _userInfo?.username ?? '调研员'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _today,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _hasTask 
                ? const Color(0xFF10B981) 
                : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _hasTask ? '有任务' : '今日休息',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 统计网格
  Widget _buildStatsGrid() {
    return Row(
      children: [
        _buildStatItem('$_todayCount', '今日任务'),
        const SizedBox(width: 8),
        _buildStatItem('$_completedCount', '已调研商品数'),
        const SizedBox(width: 8),
        _buildStatItem('$_pendingCount', '待调研商品数'),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 任务区域
  Widget _buildTaskSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '今日调研任务',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                GestureDetector(
                  onTap: _loadTasks,
                  child: const Text(
                    '刷新 ↻',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 内容
          _isLoading
            ? _buildLoading()
            : !_hasTask
              ? _buildEmptyState()
              : _buildTaskList(),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              backgroundColor: const Color(0xFFE2E8F0),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '加载中...',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(50),
      child: Column(
        children: [
          const Text('📭', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text(
            '暂无今日任务',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '休息一下吧，明天继续努力！',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildTaskCard(_tasks[index]);
      },
    );
  }

  Widget _buildTaskCard(dynamic task) {
    final items = task['items'] as List? ?? [];
    final status = task['status'] ?? 'active';
    final isCancelled = status == 'cancelled';
    final totalRecords = task['total_records'] ?? 0;
    final completionPercent = task['completion_percent'] ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCancelled ? const Color(0xFFF8FAFC) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCancelled ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
          width: isCancelled ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Expanded(
                child: Text(
                  task['title'] ?? '未命名任务',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isCancelled ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 信息行
          Row(
            children: [
              const Text('📅', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                task['date'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 20),
              const Text('📊', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                '${items.length}个商品',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          // 描述
          if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                task['description'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
          // 商品列表
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📋 调研商品', style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      )),
                      const SizedBox(width: 8),
                      Text('(已调研 $totalRecords 次)', style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      )),
                    ],
                  ),
                  if (completionPercent > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: completionPercent / 100,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ...items.map((item) => _buildItemRow(item)).toList(),
                ],
              ),
            ),
          ],
          // 底部
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                task['created_at']?.toString().substring(0, 16) ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
              if (!isCancelled)
                ElevatedButton(
                  onPressed: () => _onStartSurvey(task),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '开始调研',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic item) {
    final recordCount = item['record_count'] ?? 0;
    final hasRecords = recordCount > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasRecords ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: hasRecords ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          // 数量徽章
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: hasRecords ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$recordCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: hasRecords ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 品类标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item['category'] ?? '',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 商品名
          Expanded(
            child: Text(
              item['product_name'] ?? '',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 规格
          if (item['product_spec'] != null && item['product_spec'].toString().isNotEmpty)
            Text(
              item['product_spec'],
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFF047857);
      case 'done':
        return const Color(0xFF64748B);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF047857);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return '进行中';
      case 'done':
        return '已完成';
      case 'cancelled':
        return '已作废';
      default:
        return '进行中';
    }
  }
}
