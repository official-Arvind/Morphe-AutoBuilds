import re
with open('src/__main__.py', 'r') as f:
    content = f.read()

# Replace the "raise" in the try block
old_block = """            if attempt_idx < len(versions_to_try) - 1 and _should_retry_with_older_version(getattr(e, "output", None)):
                continue
            raise"""

new_block = """            if attempt_idx < len(versions_to_try) - 1:
                logging.warning("Patching failed. Trying older version...")
                continue
            
            logging.error(f"❌ Exhausted all version retries for this source. Moving to next if available or skipping.")
            break"""
content = content.replace(old_block, new_block)

# Wrap the `versions_to_try` block inside the method loop!
# Actually this is too complex with simple replace. Let's just catch it.

