# Native Implement packet

Wait for the bootstrap addressed to the handle bound by the coordinator. Run its
`read_command` in `read_shell` in the stated workspace. Preserve `--recipient`.
Set the tool output limit to at least 12,000 tokens and use one call per chunk.
Inspect the complete JSON and content before using `--chunk NEXT --ack ACKNOWLEDGEMENT`.
Repeat identical arguments if output is lost or truncated, even if the ACK is
visible. If the receipt was lost, restart at chunk one.

After the final complete response, append `--ack ACKNOWLEDGEMENT --materials MATERIALS`
from that response to `confirm_command`. Read the complete assignment and every
mandatory instruction. Begin writes and assigned commands only after successful
confirmation. Report any failed read or confirmation. Preserve observable read
outputs when requested.
