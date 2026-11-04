"""Generates the 128 pictures of the event and penalty cards of Redesign the City, one for every card.

Run from the project root:  python tools/gen_cards.py          (writes assets/cards/<card id>.svg)

Each picture is a small scene in the style of the game's tiles: the real tile illustrations and UI icons
(assets/tiles, assets/ui) plus hand-drawn props (card_art_props.py) on a backdrop in the card's colour. The
colour of a card comes from MOTIF_TINT in scripts/core/card_defs.gd, so the pictures follow the card data.
Godot's SVG import ignores <text> and filters, so everything is drawn with shapes and gradients.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from card_art_lib import ROOT, Pal, group, scene, tile, ui  # noqa: E402
from card_art_props import PROPS  # noqa: E402

CARDS = os.path.join(ROOT, "assets", "cards")


# Everything is drawn a little larger than laid out here, around the middle of the picture, because a card
# shows its picture quite small and the compositions below were planned on a roomier grid.
ZOOM = 1.15
SPREAD = 1.04


def _z(x, y, s):
    return 128 + (x - 128) * SPREAD, 124 + (y - 124) * SPREAD, s * ZOOM


def T(name, x, y, s=0.58, r=0, tone=None):
    zx, zy, zs = _z(x, y, s)
    return lambda a: tile(name, zx, zy, zs, r, True, tone)


def U(name, x, y, s=1.0, r=0):
    zx, zy, zs = _z(x, y, s)
    return lambda a: ui(name, zx, zy, zs, r)


def P(name, x, y, s=1.0, r=0):
    zx, zy, zs = _z(x, y, s)
    return lambda a: group(PROPS[name](a), zx, zy, zs, r)


# Cards that offer a choice get the calmer backdrop; events are "gain", penalties "loss".
CHOICE = {"mayors_reward", "planners_pick", "smart_investment", "roads_or_greenery", "mayors_medal"}

SPECS = {
    # ------------------------------------------------------------ events
    "government_funding": [P("gov", 112, 112, 0.98), P("coin_stack", 194, 172, 0.64), U("coin", 60, 184, 1.0, -12)],
    "regional_grant": [P("flag", 66, 116, 0.78), P("gov", 134, 118, 0.84), P("envelope", 186, 176, 0.62)],
    "ramps_and_lifts": [T("home_small_access", 92, 126, 0.52, -3), T("amenity_clinic", 164, 128, 0.46, 4), U("role_access", 198, 60, 1.1), U("coin", 62, 196, 1.0)],
    "lottery_win": [P("ticket", 128, 116, 1.1, -8), U("coin", 54, 62, 1.1), U("coin", 206, 70, 1.0), U("coin", 62, 188, 0.9), U("coin", 196, 184, 1.2)],
    "bank_bonus": [P("bank_building", 112, 112, 0.98), P("coin_stack", 192, 172, 0.62), P("arrow_up", 62, 178, 0.5)],
    "solidarity_fund": [P("jar", 120, 116, 1.05), U("role_child", 198, 170, 1.0), U("role_older", 56, 170, 1.0)],
    "tourist_tax": [P("suitcase", 112, 122, 1.0), P("coin_stack", 192, 170, 0.62), U("sun", 200, 62, 1.2)],
    "generous_donor": [P("money_bag", 110, 120, 1.0), P("heart_plain", 192, 162, 0.55), U("crown", 190, 60, 1.3)],
    "improved_circulation": [T("home_small_worker", 84, 110, 0.46, -4), T("road_15", 132, 130, 0.46), T("amenity_cafe", 180, 106, 0.46, 4), U("route", 196, 186, 1.3), P("badge_check", 62, 186, 0.45)],
    "clean_record": [P("ledger", 112, 116, 1.0), P("coin_stack", 192, 172, 0.58), P("badge_check", 196, 66, 0.55)],
    "green_city_award": [T("park", 88, 128, 0.5, -6), T("trees", 160, 120, 0.5, 5), P("rosette", 196, 170, 0.55)],
    "shopkeepers_guild": [T("commercial", 116, 120, 0.62), P("coin_stack", 196, 174, 0.58), U("role_worker", 58, 176, 1.2)],
    "market_day": [T("amenity_market", 80, 128, 0.46, -4), T("kiosk", 130, 114, 0.4, 3), T("supermarket", 178, 130, 0.46, 5), P("bunting", 128, 56, 0.92)],
    "campus_buzz": [T("university", 92, 124, 0.52, -4), T("library", 166, 128, 0.5, 4), U("role_student", 200, 58, 1.0), U("coin", 62, 196, 1.0)],
    "health_ministry_funding": [T("hospital", 96, 124, 0.54, -4), T("amenity_clinic", 162, 130, 0.46, 4), P("heart", 196, 62, 0.5), U("coin", 62, 196, 1.0)],
    "school_grant": [T("amenity_school", 120, 116, 0.66), P("coin_stack", 196, 172, 0.58), U("trophy", 60, 176, 1.2)],
    "parking_revenue": [T("parking", 112, 116, 0.6), P("barrier", 184, 178, 0.5), U("coin", 62, 186, 1.2)],
    "coffee_festival": [T("amenity_cafe", 116, 126, 0.62), P("bunting", 128, 58, 0.9), U("coin", 198, 178, 1.1)],
    "newcomers": [T("home_large_family", 116, 116, 0.62), P("suitcase", 198, 176, 0.5), U("role_worker", 60, 180, 1.1), U("role_child", 90, 196, 0.9)],
    "debt_relief": [P("bank_building", 100, 110, 0.9), P("doc_stamp", 182, 148, 0.8), P("badge_check", 62, 188, 0.45)],
    "roads_or_greenery": [T("road_15", 84, 126, 0.46, -4), P("badge_or", 128, 172, 0.55), T("trees", 172, 120, 0.46, 5)],
    "tree_planting_campaign": [T("trees", 108, 122, 0.6), P("shovel", 198, 122, 0.7, 12), P("badge_zero", 62, 180, 0.5)],
    "road_crew": [T("road_10", 104, 128, 0.5, -3), P("hardhat", 178, 106, 0.58), P("cone", 198, 172, 0.5), P("cone", 60, 186, 0.36)],
    "park_donation": [T("park", 118, 126, 0.62), P("bow", 188, 64, 0.7, 10)],
    "corner_shop_licence": [T("kiosk", 114, 124, 0.62), P("doc_stamp", 194, 170, 0.58, 8), P("bow", 184, 60, 0.6, 8)],
    "cafe_startup": [T("amenity_cafe", 116, 124, 0.62), P("sign_open", 194, 174, 0.55), P("bow", 186, 60, 0.6, 8)],
    "bike_lane_gift": [T("road_bike_10", 108, 124, 0.6, -3), P("bike", 182, 172, 0.52), P("bow", 188, 60, 0.6, 8)],
    "car_free_funding": [T("road_pedestrian_10", 108, 124, 0.6, -3), P("citizens3", 180, 180, 0.6), P("sign_no", 60, 66, 0.36)],
    "shade_programme": [T("road_shaded_10", 108, 124, 0.6, -3), U("sun", 192, 66, 1.5), P("bow", 190, 168, 0.5, 8)],
    "parking_donation": [T("parking", 116, 124, 0.62), P("key", 194, 174, 0.58, -15), P("bow", 186, 58, 0.6, 8)],
    "housing_subsidy": [T("home_medium_working_couple", 116, 120, 0.62), P("pricetag_down", 188, 178, 0.6)],
    "shop_sale": [T("commercial", 116, 124, 0.6), P("percent_badge", 192, 62, 0.55), P("pricetag_down", 184, 180, 0.55)],
    "embassy_reception": [T("restaurant", 100, 126, 0.56, -3), P("flag", 178, 112, 0.7), U("role_expat", 196, 178, 1.1), U("coin", 60, 190, 1.0)],
    "student_housing_fund": [T("student_large", 116, 120, 0.62), P("pricetag_down", 190, 178, 0.55), U("role_student", 60, 178, 1.1)],
    "builders_discount": [P("bricks", 100, 134, 0.95), P("hardhat", 180, 92, 0.6), P("pricetag_down", 192, 178, 0.5)],
    "extra_hands": [P("crane", 108, 116, 0.95), P("hardhat", 186, 156, 0.58), P("badge_plus", 196, 60, 0.5)],
    "luxury_housing": [T("home_large_family", 114, 120, 0.64), U("crown", 190, 58, 1.6), P("key", 192, 178, 0.52, -10)],
    "civic_pride": [P("flags_crossed", 128, 112, 1.05), U("crown", 128, 196, 1.3)],
    "neighbourhood_prize": [P("podium", 128, 130, 1.0), U("trophy", 128, 64, 1.6)],
    "student_town": [T("student_small", 84, 126, 0.5, -4), T("student_large", 158, 120, 0.52, 4), U("role_student", 198, 60, 1.1), U("sprout", 60, 194, 1.0)],
    "healthy_city": [T("amenity_clinic", 116, 124, 0.62), P("heart", 194, 170, 0.5), U("smile_up", 62, 178, 1.4)],
    "green_lungs": [P("lungs", 128, 120, 1.1), U("leaf", 62, 62, 1.6), U("leaf", 196, 64, 1.4, 30)],
    "community_day": [P("citizens3", 128, 148, 1.25), P("bunting", 128, 64, 1.0), U("event", 196, 190, 1.0)],
    "smooth_traffic": [T("road_15", 112, 126, 0.6), P("traffic_light_green", 196, 128, 0.58), U("route", 62, 180, 1.4)],
    "well_served": [T("supermarket", 78, 124, 0.42, -5), T("amenity_clinic", 128, 116, 0.42), T("amenity_school", 180, 126, 0.42, 5), P("badge_check", 128, 186, 0.55)],
    "cultural_evening": [T("library", 92, 130, 0.5, -4), T("bookshop", 164, 130, 0.5, 4), P("lanterns", 128, 56, 0.8)],
    "solar_roofs": [T("home_medium_working_couple", 108, 126, 0.6), P("solar", 192, 152, 0.55), U("sun", 196, 62, 1.6)],
    "mayors_reward": [P("medal", 96, 118, 0.9), P("badge_or", 146, 128, 0.46), U("coin", 192, 90, 1.5), U("trophy", 192, 170, 1.3)],
    "planners_pick": [T("park", 84, 126, 0.46, -4), P("badge_or", 128, 130, 0.46), P("coin_stack", 178, 132, 0.75)],
    "smart_investment": [T("amenity_cafe", 90, 124, 0.5, -4), P("badge_or", 138, 132, 0.46), P("chart", 190, 126, 0.6)],
    "festival_of_lights": [P("lanterns", 128, 92, 1.2), U("event", 196, 178, 1.2), U("sun", 60, 180, 1.0)],
    "ribbon_cutting": [P("ribbon_long", 128, 118, 1.1), P("scissors", 128, 172, 0.72, -10), U("coin", 198, 64, 1.2)],
    "heritage_prize": [P("laurel", 128, 126, 1.15), T("park", 128, 118, 0.42)],
    "clean_air_award": [T("trees", 108, 128, 0.58), P("cloud", 178, 72, 0.78), U("sun", 66, 62, 1.3), P("rosette", 196, 182, 0.46)],
    "bus_network": [P("bus", 118, 116, 1.0), U("route", 184, 186, 1.5), U("coin", 60, 190, 1.0)],
    "city_marathon": [P("banner_arch", 128, 100, 1.1), P("bike", 96, 176, 0.62), P("medal", 190, 178, 0.52)],
    "open_air_concert": [T("park", 116, 126, 0.6), P("speaker", 198, 152, 0.5), P("music", 66, 62, 0.7)],
    "rookie_boost": [T("home_small_worker", 116, 124, 0.62), U("sprout", 192, 172, 1.6), P("arrow_up", 62, 180, 0.46)],
    "food_fair": [T("restaurant", 88, 128, 0.5, -4), T("amenity_market", 160, 126, 0.5, 4), P("balloons", 196, 70, 0.5)],
    "grand_opening": [T("supermarket", 112, 126, 0.62), P("balloons", 198, 90, 0.64), U("coin", 196, 188, 1.1)],
    "scholarship_fund": [T("amenity_school", 92, 128, 0.5, -4), T("university", 162, 124, 0.5, 4), P("coin_stack", 196, 188, 0.42)],
    "sponsor_deal": [T("home_small_worker", 86, 128, 0.46, -4), T("home_medium_working_couple", 158, 122, 0.5, 4), P("banknotes", 128, 196, 0.55)],
    "community_garden": [T("park", 110, 126, 0.6), P("watering_can", 194, 172, 0.55), U("sprout", 196, 62, 1.5)],
    "mayors_medal": [P("medal", 100, 118, 1.0), U("crown", 190, 70, 1.8), P("money_bag", 192, 176, 0.5)],
    # ------------------------------------------------------------ penalties
    "environmental_fine": [P("factory", 108, 118, 1.0), P("doc_stamp", 194, 174, 0.62, 8)],
    "administrative_fee": [P("forms_stack", 102, 120, 0.98), P("stamp", 186, 104, 0.62), U("coin", 192, 188, 1.1)],
    "tax_audit": [P("ledger", 98, 122, 0.95), P("magnifier", 172, 132, 0.88)],
    "wealth_levy": [P("money_bag", 110, 120, 1.0), P("percent_badge", 192, 172, 0.58), P("arrow_down", 192, 66, 0.42)],
    "emergency_repairs": [T("home_medium_working_couple", 110, 124, 0.6), P("tools", 192, 172, 0.52), P("sign_warning", 192, 66, 0.46)],
    "loan_inspection": [P("bank_building", 100, 110, 0.9), P("magnifier", 176, 164, 0.72), P("doc", 62, 186, 0.45)],
    "construction_delays": [T("road_10", 108, 128, 0.58, -3), P("cone", 188, 160, 0.52), P("cone", 62, 176, 0.38), P("sign_warning", 192, 62, 0.44)],
    "building_maintenance": [T("home_small_worker", 112, 124, 0.6), P("hammer", 194, 150, 0.55, 20), P("hardhat", 62, 184, 0.46)],
    "parking_fines": [T("parking", 112, 124, 0.6), P("doc", 192, 166, 0.58, 8), P("sign_warning", 196, 62, 0.42)],
    "noise_complaints": [T("amenity_cafe", 100, 128, 0.56, -3), P("megaphone", 184, 112, 0.6)],
    "pickpockets": [P("mask", 112, 98, 0.9), P("wallet", 176, 172, 0.65), U("coin", 66, 186, 1.1)],
    "road_toll_dispute": [T("road_10", 106, 124, 0.56), P("barrier", 184, 176, 0.55), U("coin", 200, 68, 1.3)],
    "illegal_tree_recovery": [T("trees", 108, 124, 0.58), P("shovel", 192, 124, 0.7, 10), P("sign_warning", 62, 188, 0.4)],
    "community_complaints": [P("doc", 96, 122, 0.95), P("placard_x", 176, 112, 0.75), P("badge_minus", 196, 194, 0.36)],
    "smog_scandal": [P("newspaper", 106, 120, 0.95), P("smoke", 190, 146, 0.62)],
    "public_protest": [P("placard", 84, 110, 0.8, -8), P("placard_x", 152, 106, 0.8, 8), P("citizens3", 128, 192, 0.75)],
    "bad_press": [P("mic", 96, 110, 0.9), P("camera", 180, 154, 0.62), U("smile_down", 196, 62, 1.3)],
    "failed_inspection": [P("clipboard_x", 104, 120, 0.95), T("commercial", 182, 168, 0.4, 6, "ghost")],
    "overcrowded_flats": [T("home_large_family", 114, 116, 0.64), P("citizens3", 128, 192, 0.75), U("smile_down", 198, 62, 1.4)],
    "green_shortfall": [T("lot", 112, 126, 0.62), P("sign_no", 190, 160, 0.48)],
    "school_shortage": [T("amenity_school", 112, 124, 0.6, 0, "ghost"), P("sign_no", 190, 160, 0.46), U("role_child", 64, 182, 1.2)],
    "waiting_lists": [T("amenity_clinic", 100, 112, 0.54), P("queue4", 128, 192, 0.9), U("smile_down", 198, 64, 1.2)],
    "lift_repairs": [T("home_medium_carer", 108, 124, 0.58), P("hammer", 192, 150, 0.55, 20), P("sign_warning", 196, 62, 0.42)],
    "unemployment": [T("commercial", 110, 124, 0.58, 0, "ghost"), P("sign_closed", 192, 154, 0.5), U("role_worker", 62, 184, 1.2)],
    "traffic_chaos": [T("parking", 110, 118, 0.6), P("car", 176, 178, 0.42), P("car_blue", 84, 188, 0.38)],
    "heat_advisory": [P("thermometer", 98, 120, 1.0), U("sun", 180, 98, 1.9)],
    "debt_scandal": [P("newspaper", 104, 118, 0.95), P("padlock", 192, 168, 0.52), U("coin", 62, 188, 1.0)],
    "sinkhole": [T("road_10", 112, 108, 0.56, -4), P("hole", 150, 172, 0.75), P("cone", 62, 176, 0.38)],
    "storm_damage": [T("trees", 112, 130, 0.58), P("storm_cloud", 160, 66, 0.9), P("bolt", 198, 152, 0.56)],
    "shop_fire": [T("kiosk", 108, 130, 0.58), P("flame", 150, 142, 0.82)],
    "vandals": [T("parking", 112, 124, 0.6), P("spray", 192, 158, 0.62)],
    "flooded_streets": [T("road_15", 120, 112, 0.55), P("waves", 128, 172, 1.1)],
    "landslide": [T("road_5", 100, 112, 0.56, -3), P("rocks", 164, 172, 0.95)],
    "demolition_order": [T("commercial", 96, 120, 0.52), P("wreck", 170, 118, 0.88)],
    "beetle_attack": [T("trees", 104, 124, 0.58), P("beetle", 180, 100, 0.55, 20), P("beetle", 196, 178, 0.48, -30), P("beetle", 70, 192, 0.4, 10)],
    "park_closure": [T("park", 110, 124, 0.6), P("padlock", 186, 164, 0.56)],
    "general_strike": [P("placard", 84, 110, 0.85, -8), P("placard_text", 152, 112, 0.85, 8), P("hardhat", 128, 192, 0.55)],
    "price_hike": [P("pricetag_up", 118, 112, 1.05), P("coin_stack", 192, 172, 0.58)],
    "material_shortage": [T("home_medium_working_couple", 112, 124, 0.6, 0, "ghost"), P("pallet", 180, 178, 0.5), P("sign_warning", 196, 62, 0.42)],
    "plant_shortage": [P("pots_row", 118, 132, 1.0), P("badge_question", 196, 66, 0.48)],
    "import_duty": [P("suitcase", 100, 124, 0.88, -6), P("stamp", 184, 112, 0.76), P("percent_badge", 194, 188, 0.42)],
    "lost_permits": [P("doc", 104, 120, 0.9, -8), T("road_5", 182, 164, 0.4, 10), P("badge_question", 196, 68, 0.48)],
    "planning_dispute": [P("fence", 94, 134, 0.88), P("scales", 186, 118, 0.74)],
    "burst_pipe": [T("road_10", 106, 122, 0.56), P("waves", 150, 180, 0.7), P("wrench", 196, 98, 0.62, -20)],
    "empty_shelves": [P("shelves", 108, 124, 0.95), P("badge_x", 196, 172, 0.5)],
    "bribery_scandal": [P("envelope", 104, 120, 0.95), P("magnifier", 178, 144, 0.74), U("coin", 196, 62, 1.1)],
    "contractor_demands": [P("hardhat", 100, 112, 0.9), P("clipboard", 176, 130, 0.74), U("coin", 192, 192, 1.0)],
    "protest_march": [P("megaphone", 100, 108, 0.84), P("citizens3", 158, 180, 0.8), P("placard", 196, 96, 0.52, 10)],
    "rival_developer": [T("commercial", 84, 126, 0.46, -4), T("home_large_family", 160, 122, 0.5, 4), P("banknotes", 128, 194, 0.52)],
    "bad_day": [P("forms_stack", 100, 120, 0.9, -6), P("badge_exclaim", 186, 92, 0.52), U("smile_down", 186, 172, 1.5)],
    "power_cut": [T("home_large_family", 110, 124, 0.6, 0, "night"), P("bulb", 192, 100, 0.58), P("plug", 194, 180, 0.42)],
    "flu_season": [P("virus", 100, 114, 0.9), P("thermometer", 182, 130, 0.72, 18)],
    "tenants_strike": [T("student_small", 106, 126, 0.58), P("placard_x", 188, 122, 0.74, 8), U("role_student", 62, 186, 1.1)],
    "safety_audit": [P("hardhat", 96, 110, 0.8), P("clipboard_x", 176, 130, 0.8), P("sign_warning", 192, 194, 0.36)],
    "diplomatic_incident": [T("restaurant", 106, 126, 0.58), P("sign_warning", 192, 66, 0.46), U("role_expat", 190, 172, 1.1)],
    "gas_leak": [P("gas_cloud", 112, 100, 0.95), P("sign_warning", 184, 160, 0.62)],
    "gridlock": [T("road_15", 112, 118, 0.58), P("car", 70, 182, 0.42), P("car_blue", 150, 188, 0.42), P("traffic_light", 198, 134, 0.52)],
    "interest_due": [P("calendar", 100, 120, 0.9), P("percent_badge", 182, 100, 0.58), P("coin_stack", 192, 178, 0.52)],
    "property_tax": [T("home_large_family", 110, 120, 0.6), P("doc", 192, 156, 0.58, 8), P("percent_badge", 196, 60, 0.46)],
    "stormy_night": [P("moon", 84, 84, 0.78), P("storm_cloud", 148, 92, 0.9), P("rain", 150, 152, 0.9), P("bolt", 198, 172, 0.46)],
    "rent_hike": [T("home_small_worker", 100, 126, 0.52), P("key", 182, 154, 0.58, -10), P("pricetag_up", 182, 70, 0.52)],
    "greedy_headline": [P("newspaper", 104, 118, 0.95), P("money_bag", 192, 162, 0.58), U("crown", 62, 190, 1.0)],
    "crumbling_school": [T("amenity_school", 112, 124, 0.6), P("crack", 112, 124, 0.9), P("sign_warning", 196, 64, 0.46)],
    "overdue_taxes": [P("doc_stamp", 100, 118, 0.95), P("coin_stack", 186, 174, 0.55), P("badge_exclaim", 192, 62, 0.46)],
}


def parse_card_defs():
    """(id, type, motif) of every card and the colour of every motif, read from card_defs.gd."""
    text = open(os.path.join(ROOT, "scripts", "core", "card_defs.gd"), encoding="utf-8").read().replace("\r\n", "\n")
    tints = dict(re.findall(r'"([a-z]+)": "(#[0-9A-Fa-f]{6})"', text[text.index("const MOTIF_TINT"):text.index("const EVENT_MOTIFS")]))
    cards = []
    kind = None
    for line in text.split("\n"):
        if line.startswith("const EVENT_DATA"):
            kind = "event"
        elif line.startswith("const PENALTY_DATA"):
            kind = "penalty"
        m = re.match(r'\t\["([a-z_]+)", "[^"]*", "[^"]*", ".*", "([a-z]+)", "[^"]*",$', line)
        if m and kind:
            cards.append((m.group(1), kind, m.group(2)))
    return cards, tints


def main():
    cards, tints = parse_card_defs()
    missing = [c[0] for c in cards if c[0] not in SPECS]
    extra = [k for k in SPECS if k not in {c[0] for c in cards}]
    if missing or extra:
        raise SystemExit(f"cards without a picture: {missing}; pictures without a card: {extra}")
    os.makedirs(CARDS, exist_ok=True)
    for name in os.listdir(CARDS):
        if name.startswith("card_"):
            os.remove(os.path.join(CARDS, name))
    for cid, kind, motif in cards:
        tint = tints[motif]
        a = Pal(tint)
        mood = "choice" if cid in CHOICE else ("gain" if kind == "event" else "loss")
        body = "".join(el(a) for el in SPECS[cid])
        with open(os.path.join(CARDS, f"{cid}.svg"), "w", encoding="utf-8") as f:
            f.write(scene(tint, mood, body))
    print(f"wrote {len(cards)} card pictures")


if __name__ == "__main__":
    main()
