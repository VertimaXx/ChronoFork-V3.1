--!strict
-- Editor help and autocomplete. Runtime checks still validate every supplied value.
export type State = {[string]: boolean | number | string}
export type Volume = {kind: "box", frame: CFrame, size: Vector3}
	| {kind: "sphere", frame: CFrame, radius: number}
	| {kind: "capsule", frame: CFrame, radius: number, height: number}
export type Sweep = {kind: "sweep", start: Vector3, finish: Vector3, radius: number}
export type Snapshot = {root: CFrame, zones: {[string]: Volume}, state: State?}
export type Binding = {
	kind: string,
	capture: (serverTime: number) -> Snapshot,
	trust: ("unverified" | "serverSimulated" | "serverValidated")?,
	maxSpeed: number,
	maxRadius: number,
}
export type Profile = {
	shape: Volume | Sweep,
	targets: {string},
	opens: number?,
	closes: number?,
	maxTargets: number?,
	maxReach: number?,
	eligible: ((source: State, target: State, targetId: string, targetKind: string) -> boolean)?,
	world: boolean?,
}
-- Keep the value BeginAction returns; do not make your own table for a move reference.
export type Move = {}
export type Contact = {id: string, kind: string, zone: string, time: number, epoch: number,
	state: State, root: CFrame, distance: number, fraction: number}
export type Result = {ok: boolean, reason: string, contacts: {Contact}, time: number?,
	capturedAt: number?, rewind: number?, source: any?, shape: (Volume | Sweep)?, actor: string?}
export type CaptureResult = {ok: boolean, reason: string, time: number?,
	faults: {{id: string, reason: string}}?, contacts: {Contact}}
export type Options = {
	seconds: number?, rate: number?, maxGap: number?, maxRewind: number?,
	clock: (() -> number)?,
	resolveRewind: ((actorId: string, approvedServerContext: any, captureTime: number) -> number)?,
	world: ((queryTime: number, now: number, shape: Sweep) -> {covered: boolean, blocked: boolean?, fraction: number?})?,
}
export type Explanation = {code: string, known: boolean, subject: string?, title: string, meaning: string, fix: string}
export type Service = {
	Track: (self: Service, id: string, binding: Binding) -> (),
	Untrack: (self: Service, id: string) -> boolean,
	Discontinuity: (self: Service, id: string, reason: string?) -> (),
	Capture: (self: Service, serverTime: number?) -> CaptureResult,
	BeginAction: (self: Service, actorId: string, profile: Profile, approvedServerContext: any?) -> (Move?, string?),
	Query: (self: Service, move: Move) -> Result,
	EndAction: (self: Service, move: Move) -> boolean,
	Inspect: (self: Service) -> any,
	Destroy: (self: Service) -> (),
}
return table.freeze({})
