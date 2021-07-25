package com.bugenzhao.nga

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.bugenzhao.nga.protos.datamodel.DataModel
import com.bugenzhao.nga.protos.datamodel.configuration
import com.bugenzhao.nga.protos.datamodel.forumId
import com.bugenzhao.nga.protos.service.*
import com.google.protobuf.Message
import com.google.protobuf.Parser

private interface Callback {
    fun run(data: ByteArray?, error: String?)
}

private external fun rustCall(data: ByteArray): ByteArray
private external fun rustCallAsync(data: ByteArray, callback: Callback)

fun loadLogic() {
    System.loadLibrary("logic")
}

// examples

fun conf(path: String) {
    val request = syncRequest {
        configure = configureRequest {
            config = configuration {
                documentDirPath = path
            }
        }
    }
    logicCall(request)
}

fun auth(authInfo: DataModel.AuthInfo) {
    val request = syncRequest {
        auth = authRequest {
            info = authInfo
        }
    }
    logicCall(request, Service.AuthResponse.parser())
}

fun getExampleTopics() {
    val request = asyncRequest {
        topicList = topicListRequest {
            id = forumId {
                fid = "-7"
            }
            page = 1
        }
    }
    logicCallAsync(request, Service.TopicListResponse.parser()) {
        it.onSuccess { res ->
            print(res.topicsList)
        }
    }
}

// end of examples

fun <Response : Message> logicCallAsync(
    request: Service.AsyncRequest,
    responseParser: Parser<Response>,
    onResponse: (result: Result<Response>) -> Unit
) {
    val data = request.toByteArray()
    val callback = object : Callback {
        override fun run(data: ByteArray?, error: String?) {
            val result = when {
                data != null -> {
                    val response = responseParser.parseFrom(data)
                    Result.success(response)
                }
                else -> {
                    Log.e("logic", "logicCallAsync: $error")
                    Result.failure(Exception(error ?: "???"))
                }
            }
            Handler(Looper.getMainLooper()).post {
                onResponse(result)
            }
        }
    }
    rustCallAsync(data, callback)
}

@Throws(Exception::class)
fun <Response : Message> logicCall(
    request: Service.SyncRequest,
    responseParser: Parser<Response>
): Response {
    val data = request.toByteArray()
    val responseData = rustCall(data)
    return responseParser.parseFrom(responseData)
}

@Throws(Exception::class)
fun logicCall(
    request: Service.SyncRequest
) {
    val data = request.toByteArray()
    rustCall(data)
}
