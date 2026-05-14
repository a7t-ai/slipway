# ==========================================
# SCREENSHOT GENERATION FASTFILE
# ==========================================
# Fully autonomous App Store screenshot pipeline:
#   1. `capture_screenshots` drives the UI test target across every configured
#      device and locale from the Snapfile, writing raw PNGs to
#      fastlane/screenshots/<locale>/.
#   2. `frame_screenshots` wraps each capture in a device bezel via frameit,
#      writing `*_framed.png` next to the originals.
#   3. `python3 fastlane/marketing/generate.py` renders branded marketing
#      slides (gradient bg + tilted device + bold headline) using the framed
#      PNGs and localized copy from fastlane/screenshots/<locale>/title.strings,
#      writing them to fastlane/screenshots/<locale>/uploadable/.
#   4. `upload_to_app_store` pushes the uploadable PNGs to App Store Connect.
#
# The app detects `-UITestMode` and swaps in an in-memory SwiftData container
# seeded with deterministic fixtures plus a mocked APIClient, so captures are
# reproducible and hermetic (no network, no CloudKit).

require "fileutils"

SCREENSHOTS_DIR = File.expand_path("screenshots", __dir__).freeze
UPLOAD_STAGING_DIR = File.expand_path("screenshots_upload", __dir__).freeze

def stage_uploadable_screenshots
  FileUtils.rm_rf(UPLOAD_STAGING_DIR)
  FileUtils.mkdir_p(UPLOAD_STAGING_DIR)
  Dir.glob(File.join(SCREENSHOTS_DIR, "*", "uploadable")).each do |src|
    locale = File.basename(File.dirname(src))
    dest = File.join(UPLOAD_STAGING_DIR, locale)
    FileUtils.mkdir_p(dest)
    Dir.glob(File.join(src, "*.png")).each { |png| FileUtils.cp(png, dest) }
  end
end

platform :ios do
  desc "Capture + frame + generate uploadable App Store screenshots for every locale"
  lane :screenshots do
    capture_screenshots
    frame_screenshots(use_platform: "IOS")
    sh("cd .. && python3 fastlane/marketing/generate.py")
    UI.success("🎉 Screenshots ready at fastlane/screenshots/<locale>/uploadable/")
  end

  desc "Capture only, skip framing and marketing render"
  lane :screenshots_capture_only do
    capture_screenshots
  end

  desc "Frame existing captures with frameit"
  lane :screenshots_frame do
    frame_screenshots(use_platform: "IOS")
  end

  desc "Re-render marketing slides from existing framed captures"
  lane :screenshots_render do
    sh("cd .. && python3 fastlane/marketing/generate.py")
  end

  desc "Upload uploadable screenshots to App Store Connect"
  lane :upload_screenshots do
    UI.header("📤 Uploading Screenshots to App Store Connect")

    app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_KEY_CONTENT"],
      is_key_content_base64: true,
      in_house: false
    )

    app_id = CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier)
    app_id = app_id.is_a?(Array) ? app_id.first : app_id

    api_key = lane_context[SharedValues::APP_STORE_CONNECT_API_KEY]
    UI.user_error!("API key not configured") if api_key.nil?

    stage_uploadable_screenshots

    upload_to_app_store(
      api_key: api_key,
      app_identifier: app_id,
      skip_binary_upload: true,
      skip_metadata: true,
      skip_screenshots: false,
      overwrite_screenshots: true,
      screenshots_path: UPLOAD_STAGING_DIR,
      force: true,
      run_precheck_before_submit: false,
      submit_for_review: false,
      automatic_release: false
    )

    UI.success("🎉 Screenshots uploaded to App Store Connect")
  end
end
