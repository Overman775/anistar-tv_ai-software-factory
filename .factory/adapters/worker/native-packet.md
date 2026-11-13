# Native Implement packet

Run `read_command` in `read_shell` in the stated workspace. Keep each chunk in
its own tool result. For the next chunk use `--chunk NEXT --ack ACKNOWLEDGEMENT`
with the values from the received result. Repeat identical arguments after lost
output. If the receipt was lost, restart at chunk one.

After the final response, append `--ack ACKNOWLEDGEMENT --materials MATERIALS`
from that response to `confirm_command`. Confirm after the coordinator binds
the dispatch. Read the complete assignment and every mandatory instruction.
Begin writes and assigned commands only after successful confirmation. Report a
failed read or confirmation. Preserve observable read outputs when requested.
