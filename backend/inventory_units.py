"""Canonical quantities shared by inventory create and update operations."""

from fastapi import HTTPException

_UNITS = {
    "kg": ("g", 1000.0), "g": ("g", 1.0),
    "lb": ("g", 453.59237), "oz": ("g", 28.349523125),
    "l": ("ml", 1000.0), "ml": ("ml", 1.0),
    "u": ("Unidades", 1.0), "unidades": ("Unidades", 1.0), "unidad": ("Unidades", 1.0),
    "paquete": ("paquete", 1.0),
}


def canonical_quantity(quantity: float, unit: str) -> tuple[float, str]:
    canonical, factor = _UNITS.get(unit.strip().lower(), (unit.strip(), 1.0))
    if not canonical:
        raise HTTPException(status_code=422, detail="La unidad no puede estar vacía")
    return quantity * factor, canonical


def combine_quantities(old_quantity, old_unit, quantity, unit):
    previous, previous_unit = canonical_quantity(old_quantity, old_unit)
    incoming, incoming_unit = canonical_quantity(quantity, unit)
    if previous_unit != incoming_unit:
        raise HTTPException(
            status_code=400,
            detail="No se pueden sumar unidades incompatibles para el mismo alimento",
        )
    return previous + incoming, previous_unit
