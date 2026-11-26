import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.btl.bilingual_quiz"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.btl.bilingual_quiz"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        getByName("debug") {
            storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
        }
    }

    buildTypes {
        debug {
            // Debug chỉ đóng gói x86_64 cho máy ảo + arm64-v8a cho điện thoại thật (bỏ armeabi-v7a 32-bit cũ).
            ndk {
                abiFilters += listOf("x86_64", "arm64-v8a")
            }
        }
        release {
            signingConfig = signingConfigs.getByName("debug")
            ndk {
                abiFilters += listOf("arm64-v8a", "x86_64")
            }
        }
    }

    packaging {
        jniLibs {
            excludes += listOf("**/armeabi-v7a/**")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Không dùng C++ / FFI trong dự án -> tắt các task CMake/NDK do Flutter 3.47 tự thêm
// và cắt bỏ debug symbols trực tiếp để giảm APK từ 1.3GB xuống ~40MB mà không cần tải NDK.
fun stripElf64(file: File) {
    RandomAccessFile(file, "rw").use { raf ->
        if (raf.length() < 64L) return
        val hdr = ByteArray(64)
        raf.readFully(hdr)
        val bb = ByteBuffer.wrap(hdr).order(ByteOrder.LITTLE_ENDIAN)
        if (bb.getInt(0) != 0x464c457f) return
        val phoff = bb.getLong(32)
        val shoff = bb.getLong(40)
        val phentsize = bb.getShort(54).toInt() and 0xFFFF
        val phnum = bb.getShort(56).toInt() and 0xFFFF
        val shentsize = bb.getShort(58).toInt() and 0xFFFF
        val shnum = bb.getShort(60).toInt() and 0xFFFF
        val shstrndx = bb.getShort(62).toInt() and 0xFFFF
        if (shoff <= 0L || shnum <= 0 || shstrndx >= shnum) return

        var maxEnd = 0L
        val pbuf = ByteArray(phentsize)
        for (i in 0 until phnum) {
            raf.seek(phoff + i.toLong() * phentsize)
            raf.readFully(pbuf)
            val pb = ByteBuffer.wrap(pbuf).order(ByteOrder.LITTLE_ENDIAN)
            val offset = pb.getLong(8)
            val filesz = pb.getLong(32)
            if (offset + filesz > maxEnd) maxEnd = offset + filesz
        }
        if (maxEnd <= 64L || maxEnd >= raf.length()) return

        // Đọc section table gốc để giữ lại các section nằm trong vùng PT_LOAD (<= maxEnd)
        val shTableBytes = ByteArray(shnum * shentsize)
        raf.seek(shoff)
        raf.readFully(shTableBytes)

        val strSecPos = shstrndx * shentsize
        val strSecBuf = ByteBuffer.wrap(shTableBytes, strSecPos, shentsize).order(ByteOrder.LITTLE_ENDIAN)
        val strTabOff = strSecBuf.getLong(24)
        val strTabSize = strSecBuf.getLong(32).toInt()
        val strTab = ByteArray(strTabSize)
        raf.seek(strTabOff)
        raf.readFully(strTab)

        // Căn lề 8 byte sau maxEnd
        val alignedEnd = (maxEnd + 7L) and -8L
        val newStrTabOff = alignedEnd
        val newShOff = newStrTabOff + strTabSize.toLong()

        for (i in 0 until shnum) {
            val pos = i * shentsize
            val sb = ByteBuffer.wrap(shTableBytes, pos, shentsize).order(ByteOrder.LITTLE_ENDIAN)
            val shType = sb.getInt(4)
            val shOffset = sb.getLong(24)
            val shSize = sb.getLong(32)
            if (i == shstrndx) {
                sb.putLong(24, newStrTabOff)
            } else if (shType != 0 && shType != 8 && (shOffset + shSize > maxEnd)) {
                // Section debug nằm ngoài PT_LOAD -> chuyển thành SHT_NOBITS / rỗng
                sb.putInt(4, 0) // SHT_NULL
                sb.putLong(24, 0L)
                sb.putLong(32, 0L)
                sb.putInt(40, 0)
                sb.putInt(44, 0)
            }
        }

        bb.putLong(40, newShOff)
        raf.seek(0L)
        raf.write(hdr)
        raf.seek(newStrTabOff)
        raf.write(strTab)
        raf.seek(newShOff)
        raf.write(shTableBytes)
        raf.setLength(newShOff + shTableBytes.size.toLong())
    }
}

tasks.configureEach {
    if (name.contains("CMake", ignoreCase = true) ||
        name.contains("cxx", ignoreCase = true)
    ) {
        enabled = false
    }
    if (name == "stripDebugDebugSymbols" || name == "stripReleaseDebugSymbols" || name == "stripProfileDebugSymbols") {
        actions.clear()
        doLast {
            val variant = when {
                name.contains("Debug") -> "debug"
                name.contains("Profile") -> "profile"
                else -> "release"
            }
            val cap = variant.replaceFirstChar { it.uppercase() }
            val buildDir = project.layout.buildDirectory.get().asFile
            val inDir = File(buildDir, "intermediates/merged_native_libs/$variant/merge${cap}NativeLibs/out")
            val outDir = File(buildDir, "intermediates/stripped_native_libs/$variant/strip${cap}DebugSymbols/out")
            if (inDir.exists()) {
                File(inDir, "lib/armeabi-v7a").deleteRecursively()
                inDir.walkTopDown().filter { it.isFile && it.extension == "so" }.forEach { stripElf64(it) }
                outDir.deleteRecursively()
                inDir.renameTo(outDir)
            }
        }
    }
}
