import json
import logging
import re
import os
import shutil
from sys import exit
from pathlib import Path
from src import magisk
from os import getenv
import subprocess
from src import (
    r2,
    utils,
    release,
    downloader
)

def _should_retry_with_older_version(output: str | None) -> bool:
    """Detect common patterns that indicate the chosen app version is not
    actually compatible with the selected patches (fingerprint mismatch, etc.)."""
    if not output:
        return False
    t = output.lower()
    return (
        "failed to match the fingerprint" in t
        or "patch.patchexception" in t
        or ("fingerprint" in t and "failed" in t)
        or "patching aborted" in t
    )

def run_build(app_name: str, source: str, arch: str = "universal", is_root: bool = False) -> str:
    logging.info(f"Starting build for {app_name} (Source: {source}, Arch: {arch}, Root: {is_root})")

    cli = utils.find_cli()
    patches = utils.find_patches()

    if not cli or not patches:
        logging.error("Missing CLI or patches jar")
        return None

    is_morphe = 'morphe' in cli.name.lower() or 'morphe' in patches.name.lower()
    
    download_methods = [
        downloader.download_apkmirror,
        downloader.download_aptoide,
        downloader.download_github,
        downloader.download_uptodown,
        downloader.download_apkpure,
        downloader.download_apkcombo,
    ]

    exclude_patches = []
    include_patches = []
    
    if is_root:
        exclude_patches.extend(["-d", "microg-support", "-d", "gmscore-support", "-d", "vanced-microg-support"])

    patches_path = Path("patches") / f"{app_name}-{source}.txt"
    if patches_path.exists():
        with patches_path.open('r') as patches_file:
            for line in patches_file:
                line = line.strip()
                if line.startswith('-'):
                    exclude_patches.extend(["-d", line[1:].strip()])
                elif line.startswith('+'):
                    include_patches.extend(["-e", line[1:].strip()])

    for method in download_methods:
        logging.info(f"Trying download method: {method.__name__}")
        input_apk, version, candidates = method(app_name, str(cli), str(patches), arch)
        
        if not input_apk:
            continue
            
        versions_to_try = [version]
        if candidates and version in candidates:
            versions_to_try += [v for v in candidates if v != version]

        success = False
        signed_apk = None
        
        for attempt_idx, ver in enumerate(versions_to_try):
            if attempt_idx > 0:
                logging.warning(f"Retrying with older version {ver} due to patch failure...")
                input_apk.unlink(missing_ok=True)
                input_apk, version, _ = method(app_name, str(cli), str(patches), arch, override_version=ver)
                if input_apk is None:
                    continue

            # --- Normalize/merge input into .apk when needed ---
            if input_apk.suffix != ".apk":
                is_bundle = False
                try:
                    import zipfile
                    if zipfile.is_zipfile(input_apk):
                        with zipfile.ZipFile(input_apk, "r") as z:
                            namelist = z.namelist()
                            has_split_apks = any(n.endswith(".apk") for n in namelist)
                            is_bundle = has_split_apks or input_apk.suffix.lower() in [".apkm", ".xapk", ".apks", ".zip"]
                except Exception as e:
                    logging.debug(f"Zip inspection failed for {input_apk}: {e}")

                target_apk = input_apk.with_name(f"{input_apk.stem}.apk" if not input_apk.name.endswith(".apk") else input_apk.name)

                if is_bundle:
                    logging.info(f"Input file is a bundle ({input_apk.name}), using APKEditor to merge")
                    apk_editor = downloader.download_apkeditor()
                    merged_apk = input_apk.with_suffix(".apk")
                    merged_apk.unlink(missing_ok=True)

                    try:
                        utils.run_process([
                            "java", "-jar", str(apk_editor), "m",
                            "-f",
                            "-i", str(input_apk),
                            "-o", str(merged_apk)
                        ], silent=True, check=True)
                        input_apk.unlink(missing_ok=True)
                        input_apk = merged_apk
                    except Exception as e:
                        logging.warning(f"APKEditor merge failed ({e}); checking if file can be used as standalone APK")
                        if input_apk.exists():
                            target_apk.unlink(missing_ok=True)
                            import os
                            os.replace(input_apk, target_apk)
                            input_apk = target_apk
                else:
                    logging.info(f"Normalizing standalone APK filename to {target_apk.name}")
                    if input_apk != target_apk:
                        target_apk.unlink(missing_ok=True)
                        import os
                        os.replace(input_apk, target_apk)
                        input_apk = target_apk

                if not input_apk.exists():
                    logging.error("Processed APK file not found")
                    continue

                import re
                clean_name = re.sub(r'\(\d+\)', '', input_apk.name)  
                clean_name = re.sub(r'-\d{6,}_', '_', clean_name)  
                if clean_name != input_apk.name:
                    clean_apk = input_apk.with_name(clean_name)
                    clean_apk.unlink(missing_ok=True)
                    import os
                    os.replace(input_apk, clean_apk)
                    input_apk = clean_apk

                logging.info(f"Normalized APK file: {input_apk}")

            # --- ARCHITECTURE-SPECIFIC PROCESSING ---
            if arch != "universal":
                logging.info(f"Processing APK for {arch} architecture...")
                if arch == "arm64-v8a":
                    utils.strip_zip_entries(input_apk, ["lib/x86/*", "lib/x86_64/*", "lib/armeabi-v7a/*"])
                elif arch == "armeabi-v7a":
                    utils.strip_zip_entries(input_apk, ["lib/x86/*", "lib/x86_64/*", "lib/arm64-v8a/*"])
            else:
                utils.strip_zip_entries(input_apk, ["lib/x86/*", "lib/x86_64/*"])

            # Validate APK integrity
            logging.info("Checking APK integrity...")
            if not utils.check_apk_integrity(input_apk):
                logging.warning("APK integrity check failed; attempting repair with zip -FF if available")
                import shutil
                if shutil.which("zip"):
                    fixed_apk = Path(f"{app_name}-fixed-v{version}.apk")
                    import subprocess
                    subprocess.run([
                        "zip", "-FF", str(input_apk), "--out", str(fixed_apk)
                    ], check=False, capture_output=True)

                    if fixed_apk.exists() and fixed_apk.stat().st_size > 0:
                        if not utils.check_apk_integrity(fixed_apk):
                            logging.warning("Repair failed to produce a valid APK (missing manifest or corrupt).")
                            fixed_apk.unlink(missing_ok=True)
                            input_apk.unlink(missing_ok=True)
                            continue # Try next version
                        input_apk.unlink(missing_ok=True)
                        fixed_apk.rename(input_apk)
                        logging.info("APK fixed successfully")
                    else:
                        logging.error("Repair produced no usable file. Abandoning APK.")
                        input_apk.unlink(missing_ok=True)
                        continue
                else:
                    logging.error("zip command not available for repair. Abandoning corrupt APK.")
                    input_apk.unlink(missing_ok=True)
                    continue
            else:
                logging.info("APK integrity OK; no repair needed")

            name = config.get("name", app_name) if 'config' in locals() else app_name
            output_apk = Path(f"{app_name}-{arch}-patch-v{version}.apk")

            try:
                # USE DIFFERENT COMMANDS BASED ON SOURCE TYPE
                if is_morphe:
                    logging.info("🔧 Using Morphe patching system...")
                    morphe_cmd = [
                        "java", "-jar", str(cli),
                        "patch", "--patches", str(patches),
                        "--out", str(output_apk), str(input_apk),
                        *exclude_patches, *include_patches
                    ]
                    utils.run_process(morphe_cmd, capture=True, stream=True)
                else:
                    logging.info("🔧 Using ReVanced patching system...")
                    cli_name = Path(cli).name.lower()
                    is_revanced_v6_or_newer = (
                        'revanced-cli-6' in cli_name or 'revanced-cli-7' in cli_name or 'revanced-cli-8' in cli_name
                    )

                    if is_revanced_v6_or_newer:
                        utils.run_process([
                            "java", "-jar", str(cli),
                            "patch", "-p", str(patches), "-b",
                            "--out", str(output_apk), str(input_apk),
                            *exclude_patches, *include_patches
                        ], capture=True, stream=True)
                    else:
                        utils.run_process([
                            "java", "-jar", str(cli),
                            "patch", "--patches", str(patches),
                            "--out", str(output_apk), str(input_apk),
                            *exclude_patches, *include_patches
                        ], capture=True, stream=True)

            except subprocess.CalledProcessError as e:
                input_apk.unlink(missing_ok=True)
                output_apk.unlink(missing_ok=True)

                def _should_retry_with_older_version(output: str | None) -> bool:
                    if not output: return False
                    t = output.lower()
                    return ("failed to match the fingerprint" in t or "patch.patchexception" in t or ("fingerprint" in t and "failed" in t) or "patching aborted" in t)

                if attempt_idx < len(versions_to_try) - 1 and _should_retry_with_older_version(getattr(e, "output", None)):
                    continue
                
                logging.error(f"❌ Patching failed completely for {app_name} on version {ver}.")
                continue # Try next version or next method

            # Patch succeeded -> cleanup input and sign.
            input_apk.unlink(missing_ok=True)

            if is_root:
                signed_apk = Path(f"{app_name}-{source}-root-universal-v{version}.apk")
            else:
                signed_apk = Path(f"{app_name}-{source}-nonroot-universal-v{version}.apk")

            apksigner = utils.find_apksigner()
            if not apksigner:
                logging.error("apksigner not found")
                return None

            try:
                utils.run_process([
                    "java", "-jar", str(apksigner), "sign",
                    "--in", str(output_apk), "--out", str(signed_apk)
                ], silent=True, check=True)
                output_apk.unlink(missing_ok=True)
                success = True
                break
            except Exception as e:
                logging.error(f"Failed to sign APK: {e}")
                output_apk.unlink(missing_ok=True)
                continue

        if success and signed_apk:
            return str(signed_apk)
        else:
            logging.warning(f"Method {method.__name__} exhausted. Trying next source...")

    logging.error(f"❌ Exhausted all sources and versions for {app_name}. Build failed.")
    return None

def main():
    app_name = getenv("APP_NAME")
    source = getenv("SOURCE")

    if not app_name or not source:
        logging.error("APP_NAME and SOURCE environment variables must be set")
        exit(1)

    # Read arch-config.json
    arch_config_path = Path("arch-config.json")
    if arch_config_path.exists():
        with open(arch_config_path) as f:
            arch_config = json.load(f)
        
        # Find arches for this app
        arches = [(getenv("ARCH") or "universal").strip()]
        for config in arch_config:
            if not getenv("ARCH") and config["app_name"] == app_name and config["source"] == source:
                arches = config["arches"]
                break
        
        # Build for each architecture
        built_apks = []
        for arch in arches:
            logging.info(f"🔨 Building {app_name} for {arch} architecture (Non-Root)...")
            apk_path = run_build(app_name, source, arch, is_root=False)
            if apk_path:
                built_apks.append(apk_path)
                print(f"✅ Built {arch} version: {Path(apk_path).name}")
            
            logging.info(f"🔨 Building {app_name} for {arch} architecture (Root)...")
            root_apk_path = run_build(app_name, source, arch, is_root=True)
            if root_apk_path:

                package_name = "unknown"
                for p_conf in Path("apps").rglob(f"{app_name}.json"):
                    try:
                        with p_conf.open() as f_conf:
                            import json
                            package_name = json.load(f_conf).get("package", "unknown")
                            break
                    except:
                        pass
                zip_path = magisk.create_magisk_module(root_apk_path, app_name, "latest", source, package_name)
                if zip_path:
                    print(f"✅ Built Magisk Module: {Path(zip_path).name}")
                Path(root_apk_path).unlink(missing_ok=True) # delete root apk, keep zip

        
        # Summary
        print(f"\n🎯 Built {len(built_apks)} APK(s) for {app_name}:")
        for apk in built_apks:
            print(f"  📱 {Path(apk).name}")
        
    else:
        # Fallback to single universal build
        logging.warning("arch-config.json not found, building universal only")
        apk_path = run_build(app_name, source, "universal", is_root=False)
        if apk_path:
            print(f"🎯 Final APK path: {apk_path}")
        
        root_apk_path = run_build(app_name, source, "universal", is_root=True)
        if root_apk_path:

            package_name = "unknown"
            for p_conf in Path("apps").rglob(f"{app_name}.json"):
                try:
                    with p_conf.open() as f_conf:
                        import json
                        package_name = json.load(f_conf).get("package", "unknown")
                        break
                except:
                    pass
            zip_path = magisk.create_magisk_module(root_apk_path, app_name, "latest", source, package_name)
            if zip_path:
                print(f"🎯 Final Magisk Module path: {zip_path}")
            Path(root_apk_path).unlink(missing_ok=True)


if __name__ == "__main__":
    main()
