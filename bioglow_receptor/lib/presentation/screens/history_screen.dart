import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/history_cubit.dart';
import '../cubit/history_state.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  void _exportData(BuildContext context) async {
    final cubit = context.read<HistoryCubit>();
    try {
      final path = await cubit.exportReport();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Relatório PDF salvo com sucesso!\n$path'),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, state) {
        final isAlert = state.filter == HistoryFilter.alerts || 
            (state is HistoryLoaded && state.data.isNotEmpty && state.data.last.magnitude > HistoryCubit.thresholdWarning);
        
        return Scaffold(
          backgroundColor: isAlert ? Colors.red[50] : const Color(0xFFF1F5F9),
          appBar: AppBar(
            backgroundColor: isAlert ? Colors.redAccent : Colors.white,
            iconTheme: IconThemeData(color: isAlert ? Colors.white : Colors.blueAccent),
            title: Row(
              children: [
                Icon(
                  Icons.list_alt_rounded,
                  color: isAlert ? Colors.white : Colors.blueAccent,
                ),
                const SizedBox(width: 12),
                Text(
                  'Registro de Histórico',
                  style: TextStyle(
                    color: isAlert ? Colors.white : const Color(0xFF334155),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.1),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: 'Exportar Relatório PDF',
                onPressed: () => _exportData(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              _buildFilter(context, state),
              Expanded(child: _buildBody(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilter(BuildContext context, HistoryState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.white,
      child: SegmentedButton<HistoryFilter>(
        segments: const [
          ButtonSegment(
            value: HistoryFilter.all,
            label: Text('Todas as Leituras'),
            icon: Icon(Icons.waves_rounded),
          ),
          ButtonSegment(
            value: HistoryFilter.alerts,
            label: Text('Apenas Alertas (Críticos)'),
            icon: Icon(Icons.warning_amber_rounded),
          ),
        ],
        selected: {state.filter},
        onSelectionChanged: (Set<HistoryFilter> newSelection) {
          context.read<HistoryCubit>().changeFilter(newSelection.first);
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return state.filter == HistoryFilter.alerts ? Colors.redAccent : Colors.blueAccent;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.blueGrey;
          }),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HistoryState state) {
    if (state is HistoryLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final cubit = context.read<HistoryCubit>();
    final dataList = cubit.filteredData.reversed.toList();

    if (dataList.isEmpty) {
      return Center(
        child: Text(
          state.filter == HistoryFilter.alerts 
              ? 'Nenhum alerta crítico registrado.' 
              : 'Aguardando dados...',
          style: const TextStyle(color: Colors.black54, fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: dataList.length,
      itemBuilder: (context, index) {
        final item = dataList[index];
        final isItemAlert = item.magnitude > HistoryCubit.thresholdAlert;
        final isItemWarning = item.magnitude > HistoryCubit.thresholdWarning && item.magnitude <= HistoryCubit.thresholdAlert;
        
        Color itemColor = Colors.white;
        Color borderColor = Colors.grey.withValues(alpha: 0.2);
        Color iconBgColor = Colors.blueAccent.withValues(alpha: 0.1);
        Color iconColor = Colors.blueAccent;
        IconData itemIcon = Icons.waves_rounded;
        Color valueColor = Colors.blueGrey[800]!;

        if (isItemAlert) {
          itemColor = Colors.red[50]!;
          borderColor = Colors.redAccent.withValues(alpha: 0.3);
          iconBgColor = Colors.redAccent.withValues(alpha: 0.2);
          iconColor = Colors.redAccent;
          itemIcon = Icons.warning_rounded;
          valueColor = Colors.redAccent[700]!;
        } else if (isItemWarning) {
          itemColor = Colors.orange[50]!;
          borderColor = Colors.orange.withValues(alpha: 0.3);
          iconBgColor = Colors.orange.withValues(alpha: 0.2);
          iconColor = Colors.orange;
          itemIcon = Icons.warning_amber_rounded;
          valueColor = Colors.orange[800]!;
        }
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: borderColor,
              width: 1,
            ),
          ),
          color: itemColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    itemIcon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vibração: ${item.magnitude.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: valueColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: Colors.blueGrey[400]),
                          const SizedBox(width: 4),
                          Text(
                            'Horário: ${_formatTime(item.timestamp)}',
                            style: TextStyle(color: Colors.blueGrey[600], fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14, color: Colors.blueGrey[400]),
                          const SizedBox(width: 4),
                          Text(
                            'Data: ${_formatDate(item.timestamp)}',
                            style: TextStyle(color: Colors.blueGrey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
