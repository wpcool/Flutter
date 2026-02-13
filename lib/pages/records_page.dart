import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

// API基础URL，用于拼接图片完整路径
const String _baseUrl = 'http://8.152.197.205';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _apiService = ApiService();
  final _storage = StorageService();
  List<dynamic> _records = [];
  List<dynamic> _allRecords = []; // 所有记录，用于筛选
  bool _isLoading = true;
  
  // 日期筛选
  DateTime _selectedDate = DateTime.now();
  bool _isFiltered = false;
  
  // 7天统计
  List<Map<String, dynamic>> _weeklyStats = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final userInfo = _storage.getUserInfo();
      if (userInfo == null) {
        print('未登录，无法加载记录');
        return;
      }
      
      // 获取最近30天的记录，用于统计和显示
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final dateStr = DateFormat('yyyy-MM-dd').format(thirtyDaysAgo);
      
      print('正在加载用户 ${userInfo.id} 的记录...');
      final response = await _apiService.get('/api/records?surveyor_id=${userInfo.id}&date=$dateStr');
      
      if (response is List) {
        setState(() {
          _allRecords = response;
          _records = response;
        });
        _calculateWeeklyStats();
        print('加载了 ${response.length} 条记录');
      } else if (response is Map && response['data'] is List) {
        setState(() {
          _allRecords = response['data'];
          _records = response['data'];
        });
        _calculateWeeklyStats();
        print('加载了 ${response['data'].length} 条记录');
      }
    } catch (e) {
      print('加载记录失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 计算最近7天的统计
  void _calculateWeeklyStats() {
    final stats = <Map<String, dynamic>>[];
    final now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      // 统计这一天的记录数
      final count = _allRecords.where((r) {
        final createdAt = r['created_at']?.toString() ?? '';
        return createdAt.startsWith(dateStr);
      }).length;
      
      stats.add({
        'date': date,
        'dateStr': DateFormat('MM-dd').format(date),
        'weekday': DateFormat('E', 'zh_CN').format(date),
        'count': count,
        'isToday': i == 0,
      });
    }
    
    setState(() => _weeklyStats = stats);
  }

  // 按日期筛选
  void _filterByDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _isFiltered = true;
      
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      _records = _allRecords.where((r) {
        final createdAt = r['created_at']?.toString() ?? '';
        return createdAt.startsWith(dateStr);
      }).toList();
    });
  }

  // 清除筛选
  void _clearFilter() {
    setState(() {
      _isFiltered = false;
      _selectedDate = DateTime.now();
      _records = _allRecords;
    });
  }

  // 选择日期
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );
    
    if (picked != null) {
      _filterByDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('调研记录'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          // 日期筛选按钮
          TextButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            label: Text(
              _isFiltered ? DateFormat('MM-dd').format(_selectedDate) : '筛选',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (_isFiltered)
            IconButton(
              onPressed: _clearFilter,
              icon: const Icon(Icons.clear, color: Colors.white),
              tooltip: '清除筛选',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecords,
              color: const Color(0xFF6366F1),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // 7天统计卡片
                    _buildWeeklyStatsCard(),
                    // 记录列表
                    _buildRecordsList(),
                  ],
                ),
              ),
            ),
    );
  }

  // 7天统计卡片
  Widget _buildWeeklyStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '近7天调研统计',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              children: _weeklyStats.map((day) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _filterByDate(day['date']),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isFiltered && 
                                DateFormat('yyyy-MM-dd').format(_selectedDate) == 
                                DateFormat('yyyy-MM-dd').format(day['date'])
                            ? const Color(0xFF6366F1)
                            : day['isToday']
                                ? const Color(0xFFEEF2FF)
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: day['isToday'] && !_isFiltered
                              ? const Color(0xFF6366F1)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            day['weekday'],
                            style: TextStyle(
                              fontSize: 12,
                              color: _isFiltered && 
                                      DateFormat('yyyy-MM-dd').format(_selectedDate) == 
                                      DateFormat('yyyy-MM-dd').format(day['date'])
                                  ? Colors.white70
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            day['dateStr'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _isFiltered && 
                                      DateFormat('yyyy-MM-dd').format(_selectedDate) == 
                                      DateFormat('yyyy-MM-dd').format(day['date'])
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: day['count'] > 0
                                  ? (_isFiltered && 
                                          DateFormat('yyyy-MM-dd').format(_selectedDate) == 
                                          DateFormat('yyyy-MM-dd').format(day['date'])
                                      ? Colors.white.withOpacity(0.3)
                                      : const Color(0xFF6366F1).withOpacity(0.1))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${day['count']}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _isFiltered && 
                                        DateFormat('yyyy-MM-dd').format(_selectedDate) == 
                                        DateFormat('yyyy-MM-dd').format(day['date'])
                                    ? Colors.white
                                    : day['count'] > 0
                                        ? const Color(0xFF6366F1)
                                        : Colors.grey[400],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // 总记录数
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isFiltered
                    ? '${DateFormat('yyyy年MM月dd日').format(_selectedDate)} 共 ${_records.length} 条记录'
                    : '共 ${_records.length} 条记录',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (_isFiltered)
                TextButton(
                  onPressed: _clearFilter,
                  child: const Text('查看全部'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    if (_records.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(50),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _isFiltered ? '该日期暂无记录' : '暂无记录',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        return _buildRecordCard(_records[index]);
      },
    );
  }

  Widget _buildRecordCard(dynamic record) {
    final photos = record['photos'] as List? ?? [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showRecordDetail(record),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 时间
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      record['created_at']?.toString().substring(11, 16) ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 类别标签
                  if (record['category'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record['category'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record['product_name'] ?? '未知商品',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${record['own_store_name'] ?? ''} → ${record['store_name'] ?? ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '¥${record['price'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(
                              photos[index].startsWith('http') 
                                ? photos[index] 
                                : '$_baseUrl${photos[index]}',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 显示记录详情
  void _showRecordDetail(dynamic record) {
    final photos = record['photos'] as List? ?? [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // 拖动条
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 商品名
              Text(
                record['product_name'] ?? '未知商品',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // 类别
              if (record['category'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record['category'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // 价格
              _buildDetailRow('价格', '¥${record['price'] ?? 0}'),
              // 门店信息
              _buildDetailRow('自己门店', record['own_store_name'] ?? '-'),
              _buildDetailRow('竞店', record['store_name'] ?? '-'),
              // 地址
              if (record['store_address'] != null)
                _buildDetailRow('地址', record['store_address']),
              // 坐标
              if (record['latitude'] != null && record['longitude'] != null)
                _buildDetailRow('坐标', '${record['latitude']}, ${record['longitude']}'),
              // 促销信息
              if (record['promotion_info'] != null)
                _buildDetailRow('促销', record['promotion_info']),
              // 备注
              if (record['remark'] != null)
                _buildDetailRow('备注', record['remark']),
              // 时间
              _buildDetailRow('创建时间', record['created_at']?.toString().substring(0, 19) ?? '-'),
              // 图片
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  '照片',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...photos.map((url) {
                  final fullUrl = url.startsWith('http') ? url : '$_baseUrl$url';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        fullUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.error)),
                          );
                        },
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
