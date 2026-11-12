class_name AeroPhysics
extends RefCounted

## Motor de física aeroespacial y diagnóstico de causa-efecto.

const BASE_BUS_MASS_KG: float = 160.0
const BASE_BUS_COST_M: float = 15.0
const BASE_BUS_POWER_USE_W: float = 45.0
const BASE_BUS_BATTERY_WH: float = 200.0
const MAX_HOLO_VOLUME: float = 8.5

static func evaluate_spacecraft(
	placed_parts: Array[Dictionary],
	rocket_id: String,
	altitude_km: float,
	inclination_deg: float,
	antenna_freq_mhz: float,
	target_freq_mhz: float,
	disabled_part_indices: Array[int] = []
) -> Dictionary:
	var rocket: Dictionary = CatalogData.get_rocket_by_id(rocket_id)
	
	var total_mass: float = BASE_BUS_MASS_KG
	var parts_cost: float = BASE_BUS_COST_M
	var power_gen: float = 0.0
	var power_use: float = BASE_BUS_POWER_USE_W
	var battery_cap: float = BASE_BUS_BATTERY_WH
	var total_science: int = 0
	var active_science: int = 0
	var data_rate_mbps: float = 0.0
	var raw_bandwidth_mbps: float = 0.0
	var rcs_fuel: float = 25.0 # Reserva mínima del bus
	var bonus_delta_v: float = 0.0
	var total_volume: float = 0.6

	for i in range(placed_parts.size()):
		var entry: Dictionary = placed_parts[i]
		var part: Dictionary = CatalogData.get_part_by_id(entry.get("part_id", ""))
		if part.is_empty():
			continue
		var is_disabled: bool = disabled_part_indices.has(i)
		total_mass += float(part["mass"])
		parts_cost += float(part["cost"])
		power_gen += float(part["power_gen"])
		battery_cap += float(part["battery_cap"])
		rcs_fuel += float(part["rcs_fuel"])
		bonus_delta_v += float(part["delta_v_bonus"])
		raw_bandwidth_mbps += float(part["bandwidth"])
		
		var sz: Vector3 = part["size"]
		total_volume += sz.x * sz.y * sz.z
		
		total_science += int(part["science"])
		if not is_disabled:
			power_use += float(part["power_use"])
			active_science += int(part["science"])
			data_rate_mbps += float(part["data_rate"])

	var rocket_cost: float = float(rocket["cost"])
	var total_cost: float = parts_cost + rocket_cost
	var max_payload: float = float(rocket["max_payload_kg"])
	
	# Relación Empuje-Peso (TWR) efectiva según carga útil
	var payload_ratio: float = total_mass / max(max_payload, 1.0)
	var twr: float = clampf(1.85 / max(payload_ratio, 0.25), 0.35, 3.2)
	
	# Delta-V requerido según altitud (LEO ~7800, MEO ~9600, GEO ~11900) e inclinación
	var alt_factor: float = clampf(inverse_lerp(200.0, 36000.0, altitude_km), 0.0, 1.2)
	var required_dv: float = 7650.0 + pow(alt_factor, 0.65) * 4100.0 + abs(inclination_deg - 28.5) * 8.5
	
	# Penalización de Delta-V si la nave es muy pesada para el cohete
	var mass_penalty_dv: float = max(0.0, (total_mass - max_payload * 0.75) * 1.45)
	var available_dv: float = float(rocket["base_delta_v"]) + bonus_delta_v - mass_penalty_dv

	# Fricción atmosférica exponencial debajo de 320 km
	var atmo_drag: float = 0.0
	if altitude_km < 340.0:
		atmo_drag = clampf((340.0 - altitude_km) / 180.0, 0.0, 1.5)

	# Atenuación por distancia y calibración de antena
	var distance_loss: float = lerpf(1.0, 0.62, clampf(altitude_km / 36000.0, 0.0, 1.0))
	var freq_error: float = abs(antenna_freq_mhz - target_freq_mhz)
	var calibration_efficiency: float = clampf(1.0 - (freq_error / 650.0), 0.15, 1.0)
	var effective_bandwidth: float = raw_bandwidth_mbps * distance_loss * calibration_efficiency

	return {
		"total_mass": total_mass,
		"max_payload": max_payload,
		"parts_cost": parts_cost,
		"rocket_cost": rocket_cost,
		"total_cost": total_cost,
		"power_gen": power_gen,
		"power_use": power_use,
		"power_net": power_gen - power_use,
		"battery_cap": battery_cap,
		"total_science": total_science,
		"active_science": active_science,
		"data_rate_mbps": data_rate_mbps,
		"raw_bandwidth_mbps": raw_bandwidth_mbps,
		"effective_bandwidth": effective_bandwidth,
		"calibration_efficiency": calibration_efficiency,
		"rcs_fuel": rcs_fuel,
		"twr": twr,
		"required_dv": required_dv,
		"available_dv": available_dv,
		"atmo_drag": atmo_drag,
		"total_volume": total_volume,
		"max_volume": MAX_HOLO_VOLUME
	}
