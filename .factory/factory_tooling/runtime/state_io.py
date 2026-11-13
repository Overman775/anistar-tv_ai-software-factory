"""Validate persisted state at read and write boundaries."""

from pydantic import TypeAdapter, ValidationError

from factory_tooling.runtime.contracts import Report, ReportDraft, State
from factory_tooling.runtime.workflow_core import Invalid
from factory_tooling.validation import validation_message

STATE = TypeAdapter[State](State)


def parse_state(value: object) -> State:
    try:
        return STATE.validate_python(value)
    except ValidationError as exc:
        raise Invalid(validation_message("Invalid persisted state", exc, STATE)) from None


REPORT = TypeAdapter[Report](Report)


def parse_report(value: object) -> Report:
    try:
        return REPORT.validate_python(value)
    except ValidationError as exc:
        raise Invalid(validation_message("Invalid workflow report", exc, REPORT)) from None


DRAFT = TypeAdapter[ReportDraft](ReportDraft)


def parse_report_draft(value: object) -> ReportDraft:
    try:
        return DRAFT.validate_python(value)
    except ValidationError as exc:
        raise Invalid(validation_message("Invalid workflow report draft", exc, DRAFT)) from None
