package com.example.bioglow_receptor

import android.app.Activity
import android.content.ClipData
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * A rede "Bioglow_Boia" (Access Point do ESP32) não tem internet. Nesse caso
 * o Android costuma manter os dados móveis como rede padrão e o WebSocket
 * para 192.168.4.1 sai pela rede errada e falha.
 *
 * Para evitar isso, o processo do app é vinculado à rede Wi-Fi enquanto ela
 * estiver disponível (com ou sem internet) e desvinculado quando ela cair.
 *
 * Também expõe o canal "bioglow/arquivos" para gerar, compartilhar e salvar
 * arquivos .CSV reais no Android/Tablet sem depender de plugins externos.
 */
class MainActivity : FlutterActivity() {
    private var connectivity: ConnectivityManager? = null
    private var wifiCallback: ConnectivityManager.NetworkCallback? = null

    private var conteudoCsvPendente: String? = null
    private var resultadoSalvarPendente: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        vincularAoWifi()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CANAL_ARQUIVOS
        ).setMethodCallHandler { call, result ->
            val nome = call.argument<String>("nome") ?: "bioglow_dados.csv"
            val conteudo = call.argument<String>("conteudo") ?: ""
            val titulo = call.argument<String>("titulo") ?: "Exportar CSV Bioglow"

            when (call.method) {
                "compartilharCsv" -> {
                    try {
                        compartilharArquivoCsv(nome, conteudo, titulo)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Erro ao compartilhar CSV", e)
                        result.error("ERRO_COMPARTILHAR", e.message, null)
                    }
                }
                "salvarCsv" -> {
                    try {
                        iniciarSalvarArquivoCsv(nome, conteudo, result)
                    } catch (e: Exception) {
                        Log.e(TAG, "Erro ao iniciar salvamento CSV", e)
                        result.error("ERRO_SALVAR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun gravarArquivoCache(nome: String, conteudo: String): File {
        val pasta = File(cacheDir, PASTA_EXPORTACOES)
        if (!pasta.exists()) pasta.mkdirs()
        val nomeSeguro = nome.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        val arquivo = File(pasta, nomeSeguro)
        // Adiciona BOM UTF-8 (\uFEFF) para que o Excel reconheça acentos e °C / µS/cm
        val textoComBom = if (conteudo.startsWith("\uFEFF")) conteudo else "\uFEFF$conteudo"
        arquivo.writeText(textoComBom, Charsets.UTF_8)
        return arquivo
    }

    private fun compartilharArquivoCsv(nome: String, conteudo: String, titulo: String) {
        val arquivo = gravarArquivoCache(nome, conteudo)
        val authority = "$packageName.csvprovider"
        val uri = Uri.parse("content://$authority/${arquivo.name}")

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/csv"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, titulo)
            putExtra(Intent.EXTRA_TITLE, arquivo.name)
            clipData = ClipData.newRawUri(arquivo.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val chooser = Intent.createChooser(intent, titulo).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(chooser)
    }

    private fun iniciarSalvarArquivoCsv(
        nome: String,
        conteudo: String,
        result: MethodChannel.Result
    ) {
        resultadoSalvarPendente?.success(false)
        conteudoCsvPendente = if (conteudo.startsWith("\uFEFF")) conteudo else "\uFEFF$conteudo"
        resultadoSalvarPendente = result

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/csv"
            putExtra(Intent.EXTRA_TITLE, nome)
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQ_SALVAR_CSV)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_SALVAR_CSV) return

        val res = resultadoSalvarPendente
        val texto = conteudoCsvPendente
        resultadoSalvarPendente = null
        conteudoCsvPendente = null

        if (res == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null || texto == null) {
            res.success(false)
            return
        }

        try {
            val uri: Uri = data.data!!
            contentResolver.openOutputStream(uri)?.use { out ->
                out.write(texto.toByteArray(Charsets.UTF_8))
                out.flush()
            }
            res.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Falha ao gravar CSV escolhido pelo usuário", e)
            res.error("ERRO_GRAVACAO", e.message, null)
        }
    }

    override fun onDestroy() {
        desvincularDoWifi()
        super.onDestroy()
    }

    private fun vincularAoWifi() {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
        connectivity = cm

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            // Sem exigir internet: a rede da boia é local.
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                Log.d(TAG, "Wi-Fi disponível; vinculando processo.")
                cm.bindProcessToNetwork(network)
            }

            override fun onLost(network: Network) {
                if (cm.boundNetworkForProcess == network) {
                    Log.d(TAG, "Wi-Fi perdido; desvinculando processo.")
                    cm.bindProcessToNetwork(null)
                }
            }
        }

        try {
            cm.registerNetworkCallback(request, callback)
            wifiCallback = callback
        } catch (e: Exception) {
            Log.w(TAG, "Não foi possível monitorar o Wi-Fi", e)
        }
    }

    private fun desvincularDoWifi() {
        val cm = connectivity ?: return
        wifiCallback?.let {
            try {
                cm.unregisterNetworkCallback(it)
            } catch (_: Exception) {
            }
        }
        wifiCallback = null
        cm.bindProcessToNetwork(null)
    }

    companion object {
        private const val TAG = "Bioglow"
        private const val CANAL_ARQUIVOS = "bioglow/arquivos"
        private const val REQ_SALVAR_CSV = 4201
        const val PASTA_EXPORTACOES = "exportacoes"
    }
}

/**
 * ContentProvider enxuto para compartilhar os arquivos .CSV gerados em
 * `cacheDir/exportacoes` com outros aplicativos (WhatsApp, Drive, E-mail, etc.).
 */
class CsvFileProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    private fun resolverArquivo(uri: Uri): File? {
        val ctx = context ?: return null
        val nome = uri.lastPathSegment ?: return null
        if (nome.contains("..") || nome.contains("/") || nome.contains("\\")) return null
        val pasta = File(ctx.cacheDir, MainActivity.PASTA_EXPORTACOES)
        val arquivo = File(pasta, nome)
        return if (arquivo.exists() && arquivo.isFile) arquivo else null
    }

    override fun getType(uri: Uri): String = "text/csv"

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor? {
        val arquivo = resolverArquivo(uri) ?: return null
        val colunas = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val valores = arrayOfNulls<Any>(colunas.size)
        for (i in colunas.indices) {
            when (colunas[i]) {
                OpenableColumns.DISPLAY_NAME -> valores[i] = arquivo.name
                OpenableColumns.SIZE -> valores[i] = arquivo.length()
            }
        }
        return MatrixCursor(colunas, 1).apply { addRow(valores) }
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        val arquivo = resolverArquivo(uri) ?: return null
        return ParcelFileDescriptor.open(arquivo, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?
    ): Int = 0
}
