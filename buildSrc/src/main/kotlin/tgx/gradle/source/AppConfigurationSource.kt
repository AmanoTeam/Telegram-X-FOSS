package tgx.gradle.source

import ApplicationConfig
import BuildVersions
import PullRequest
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.ValueSource
import org.gradle.api.provider.ValueSourceParameters
import tgx.gradle.getIntOrThrow
import tgx.gradle.getOrThrow
import tgx.gradle.loadProperties
import java.util.*

private fun getOrDefault(properties: Properties, key: String, defaults: Properties): String {
  return properties.getProperty(key, null) ?: defaults.getOrThrow(key)
}

abstract class AppConfigurationSource : ValueSource<ApplicationConfig, AppConfigurationSource.Params> {
  interface Params : ValueSourceParameters {
    val version: RegularFileProperty
    val properties: RegularFileProperty
    val defaults: RegularFileProperty
  }

  override fun obtain(): ApplicationConfig {
    val version = loadProperties(parameters.version.get().asFile)
    val properties = loadProperties(parameters.properties.get().asFile)
    val defaults = loadProperties(parameters.defaults.get().asFile)

    val applicationName = getOrDefault(properties, "app.name", defaults)
    val applicationId = getOrDefault(properties, "app.id", defaults)
    val isExampleBuild = applicationId.matches(Regex(
      "^(?:com|org)\\.example\\.(?:\\.[a-z]+)+$"
    ))
    val isExperimentalBuild =
      isExampleBuild ||
      properties.getProperty("app.experimental", "false") == "true"
    val applicationExtension = getOrDefault(properties, "tgx.extension", defaults).also {
      require(it == "none" || it == "hms")
    }

    return ApplicationConfig(
      // local.properties & local.properties.sample
      sdkDir =
        properties.getOrThrow("sdk.dir"),
      applicationName =
        applicationName,
      applicationId =
        applicationId,
      extension =
        applicationExtension,
      sourceCodeUrl =
        properties.getProperty("app.sources_url", ""),
      isExperimentalBuild =
        isExperimentalBuild,
      isHuaweiBuild =
        applicationExtension == "hms",
      forceOptimize =
        properties.getProperty("app.forceoptimize")?.toBoolean() ?: false,
      doNotObfuscate =
        isExampleBuild ||
          properties.getProperty("app.dontobfuscate")?.toBoolean() ?: false,
      telegramApiId =
        105810,
      telegramApiHash =
        "3e7a52498eec003c5896a330e5d29397",
      safetyNetToken =
        properties.getProperty("safetynet.api_key", ""),
      appDownloadUrl =
        getOrDefault(properties, "app.download_url", defaults),
      googlePlayUrl =
        properties.getProperty("app.google_download_url", null),
      galaxyStoreUrl =
        properties.getProperty("app.galaxy_download_url", null),
      huaweiAppGalleryUrl =
        properties.getProperty("app.huawei_download_url", null),
      amazonAppStoreUrl =
        properties.getProperty("app.amazon_download_url", null),
      pullRequests =
        properties.getProperty("pr.ids", "").split(',').filter { it.matches(Regex("^[0-9]+$")) }.map {
          PullRequest(it.toLong(), properties)
        }.sortedBy { it.id },
      outputFileNamePrefix =
        properties.getProperty("app.file", null) ?:
        applicationName.replace(" ", "-").replace("#", ""),

      // version.properties
      applicationVersion =
        properties.getProperty("app.version", "0").toInt().takeIf { versionOverride ->
          versionOverride > 0
        } ?:
        version.getOrThrow("version.app").toInt(),
      build = BuildVersions(version),
      majorVersion =
        version.getOrThrow("version.major").toInt(),
      nativeLibraryVersion =
        version.getProperty("version.jni"),
      leveldbVersion =
        version.getProperty("version.leveldb"),
      emojiVersion =
        version.getIntOrThrow("version.emoji"),
      creationDateMillis =
        version.getOrThrow("version.creation").toLong(),
    )
  }
}