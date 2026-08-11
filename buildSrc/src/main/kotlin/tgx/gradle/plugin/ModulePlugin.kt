package tgx.gradle.plugin

import Abi
import Config
import Sdk
import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension
import com.android.build.api.dsl.TestExtension
import com.android.build.api.variant.LibraryAndroidComponentsExtension
import com.android.build.gradle.ProguardFiles
import org.gradle.accessors.dm.LibrariesForLibs
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.tasks.compile.JavaCompile
import org.gradle.kotlin.dsl.*
import tgx.gradle.findExtraFolders
import tgx.gradle.ndkVersionMajor
import tgx.gradle.ndkVersionToMinSdk
import tgx.gradle.source.AppBuildVersionSource
import java.io.File

@Suppress("UnstableApiUsage")
open class ModulePlugin : Plugin<Project> {
  override fun apply(project: Project) {
    val config = try {
      project.extensions.getByType<AppConfigurationExtension>().config.get()
    } catch (_: Exception) {
      null
    }
    val useLegacyNdk = try {
      project.extensions.getByType<AppConfigurationExtension>().useLegacyNdk.get()
    } catch (_: Exception) {
      project.providers.gradleProperty("useLegacyNdk").map {
        it.toBoolean()
      }.getOrElse(false)
    }
    val build by lazy {
      config?.build ?:
      project.providers.of(AppBuildVersionSource::class) {
        parameters.version.set(
          project.isolated.rootProject.projectDirectory.file("version.properties")
        )
      }.get()
    }

    val libs = project.the<LibrariesForLibs>()
    project.dependencies {
      add("coreLibraryDesugaring", libs.desugaring)
    }

    project.afterEvaluate {
      tasks.withType(JavaCompile::class.java).configureEach {
        options.compilerArgs.addAll(listOf(
          "-Xmaxerrs", "2000",
          "-Xmaxwarns", "2000",

          "-Xlint:all",
          "-Xlint:unchecked",

          "-Xlint:-serial",
          "-Xlint:-lossy-conversions",
          "-Xlint:-overloads",
          "-Xlint:-overrides",
          "-Xlint:-this-escape",
          // "-Xlint:-dangling-doc-comments",

          // TODO: fix deprecation warnings by migrating to newer APIs.
          "-Xlint:-deprecation",
        ))
      }
    }

    val androidExt = project.extensions.getByName("android")

    androidExt.apply {
      when (this) {
        is LibraryExtension -> {
          buildToolsVersion = build.buildToolsVersion
          ndkVersion = if (useLegacyNdk) {
            build.legacyNdkVersion
          } else {
            build.primaryNdkVersion
          }
          compileSdk {
            version = release(build.compileSdkVersion)
          }
          lint {
            checkReleaseBuilds = false
            disable += "LintError"
            // baseline = File("lint-baseline.xml")
          }
          compileOptions {
            isCoreLibraryDesugaringEnabled = true
            sourceCompatibility = Config.JAVA_VERSION
            targetCompatibility = Config.JAVA_VERSION
          }
          testOptions {
            unitTests.isReturnDefaultValues = true
          }
          sourceSets.configureEach {
            jniLibs.directories += "jniLibs"
          }

          defaultConfig {
            minSdk = maxOf(
              Config.MIN_SDK_VERSION,
              ndkVersion.ndkVersionToMinSdk()
            )
            multiDexEnabled = true
          }
          flavorDimensions += arrayOf("SDK", "ABI")
          productFlavors {
            Abi.VARIANTS.forEach { (_, variant) ->
              register(variant.flavor) {
                dimension = "ABI"
                ndkVersion = if (variant.is64Bit) {
                  build.primaryNdkVersion
                } else {
                  build.legacyNdkVersion
                }
                ndk.abiFilters.addAll(variant.filters)
                externalNativeBuild.ndkBuild.abiFilters(*variant.filters)
                externalNativeBuild.cmake.abiFilters(*variant.filters)
              }
            }
            Sdk.VARIANTS.forEach { (_, variant) ->
              register(variant.flavor) {
                dimension = "SDK"
                externalNativeBuild.cmake.arguments(
                  "-DANDROID_PLATFORM=android-${maxOf(variant.minSdk, ndkVersion.ndkVersionToMinSdk())}",
                  "-DANDROID_STL=${if (ndkVersion.ndkVersionMajor() == 27) "c++_shared" else "c++_static"}",
                  "-DTGX_FLAVOR=${variant.flavor}"
                )
                sourceSets.getByName(variant.flavor) {
                  val extraFolders = findExtraFolders(variant)
                  extraFolders.forEach { folderName ->
                    kotlin.directories += "src/$folderName/kotlin"
                    java.directories += "src/$folderName/java"
                    res.directories += "src/$folderName/res"
                  }
                }
              }
            }
          }

          project.extensions.getByType(LibraryAndroidComponentsExtension::class.java).beforeVariants { variantBuilder ->
            val sdkFlavor = variantBuilder.productFlavors.first { it.first == "SDK" }.second
            val sdkVariant = Sdk.VARIANTS.values.first { it.flavor == sdkFlavor }
            val abiFlavor = variantBuilder.productFlavors.first { it.first == "ABI" }.second
            val abiVariant = Abi.VARIANTS.values.first { it.flavor == abiFlavor }
            variantBuilder.enable = sdkVariant.minSdk >= abiVariant.minSdk &&
              (variantBuilder.buildType != "debug" || abiVariant.flavor == "universal")
          }
        }

        is ApplicationExtension -> {
          buildToolsVersion = build.buildToolsVersion
          ndkVersion = if (useLegacyNdk) {
            build.primaryNdkVersion
          } else {
            build.legacyNdkVersion
          }
          compileSdk {
            version = release(build.compileSdkVersion)
          }
          lint {
            checkReleaseBuilds = false
            disable += "LintError"
            baseline = File("lint-baseline.xml")
          }
          compileOptions {
            isCoreLibraryDesugaringEnabled = true
            sourceCompatibility = Config.JAVA_VERSION
            targetCompatibility = Config.JAVA_VERSION
          }
          testOptions {
            unitTests.isReturnDefaultValues = true
          }
          sourceSets.configureEach {
            jniLibs.directories += "jniLibs"
          }

          defaultConfig {
            minSdk = maxOf(
              Config.MIN_SDK_VERSION,
              ndkVersion.ndkVersionToMinSdk()
            )
            targetSdk = build.targetSdkVersion
            multiDexEnabled = true
          }
          config?.let { config ->
            buildTypes {
              getByName("debug") {
                isDebuggable = true
                isJniDebuggable = true
                isMinifyEnabled = false

                ndk.debugSymbolLevel = "full"

                if (config.forceOptimize) {
                  proguardFiles(
                    getDefaultProguardFile(ProguardFiles.ProguardFile.OPTIMIZE.fileName),
                    "proguard-rules.pro"
                  )
                }
              }

              getByName("release") {
                isMinifyEnabled = !config.doNotObfuscate
                isShrinkResources = !config.doNotObfuscate

                ndk.debugSymbolLevel = "full"

                proguardFiles(
                  getDefaultProguardFile(ProguardFiles.ProguardFile.OPTIMIZE.fileName),
                  "proguard-rules.pro"
                )
              }
            }
          }
        }

        is TestExtension -> {
          buildToolsVersion = build.buildToolsVersion
          ndkVersion = if (useLegacyNdk) {
            build.legacyNdkVersion
          } else {
            build.primaryNdkVersion
          }
          compileSdk {
            version = release(build.compileSdkVersion)
          }
          compileOptions {
            isCoreLibraryDesugaringEnabled = true
            sourceCompatibility = Config.JAVA_VERSION
            targetCompatibility = Config.JAVA_VERSION
          }
          defaultConfig {
            minSdk = maxOf(
              Config.MIN_SDK_VERSION,
              ndkVersion.ndkVersionToMinSdk()
            )
            multiDexEnabled = true
          }
          sourceSets.configureEach {
            jniLibs.directories += "jniLibs"
          }

          config?.let { config ->
            buildTypes {
              getByName("debug") {
                isDebuggable = true
                isJniDebuggable = true
                isMinifyEnabled = false

                ndk.debugSymbolLevel = "full"

                if (config.forceOptimize) {
                  proguardFiles(
                    getDefaultProguardFile(ProguardFiles.ProguardFile.OPTIMIZE.fileName),
                    "proguard-rules.pro"
                  )
                }
              }

              getByName("release") {
                isMinifyEnabled = !config.doNotObfuscate
                isShrinkResources = !config.doNotObfuscate

                ndk.debugSymbolLevel = "full"

                proguardFiles(
                  getDefaultProguardFile(ProguardFiles.ProguardFile.OPTIMIZE.fileName),
                  "proguard-rules.pro"
                )
              }
            }
          }
        }

        else -> {
          error(this)
        }
      }
    }
  }
}