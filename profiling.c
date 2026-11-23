#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreserved-identifier"
#include <tracy/TracyC.h>
#pragma clang diagnostic pop

#include <tcl.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#pragma clang diagnostic ignored "-Wc++98-compat"
#pragma clang diagnostic ignored "-Wdeclaration-after-statement"

int Profiling_Init(Tcl_Interp *);

static TracyCZoneCtx ctx_stack[8192];
static uint32_t      ctx_stack_at;

static int
enter(ClientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	// objv[1] = name
	// objv[2] = command
	// objv[3] = operation
	if(objc != 4)
	{
		Tcl_WrongNumArgs(interp, 1, objv, "name command operation");
		return TCL_ERROR;
	}
	if(ctx_stack_at >= 8192)
	{
		// Too many stackframes... ignoring
		++ctx_stack_at;
		return TCL_OK;
	}
	auto name                 = Tcl_GetString(objv[1]);
	auto location             = ___tracy_alloc_srcloc(0, NULL, 0, name, strlen(name), 0);
	ctx_stack[ctx_stack_at++] = ___tracy_emit_zone_begin_alloc(location, 1);
	return TCL_OK;
}

static int
leave(ClientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	// objv[1] = name
	// objv[2] = command
	// objv[3] = code
	// objv[4] = result
	// objv[5] = operation
	if(objc != 6)
	{
		Tcl_WrongNumArgs(interp, 1, objv, "name command code result operation");
		return TCL_ERROR;
	}
	if(ctx_stack_at == 0) return TCL_OK;
	--ctx_stack_at;
	if(ctx_stack_at >= 8192)
	{
		// Too many stackframes... ignoring
		return TCL_OK;
	}

	auto   command = Tcl_GetString(objv[2]);
	size_t command_len;
	for(command_len = 0; command_len < 100; ++command_len)
	{
		if(command[command_len] == '\0') break;
	}
	auto   result = Tcl_GetString(objv[4]);
	size_t result_len;
	for(result_len = 0; result_len < 100; ++result_len)
	{
		if(result[result_len] == '\0') break;
	}

	___tracy_emit_zone_text(ctx_stack[ctx_stack_at], command, command_len);
	___tracy_emit_zone_text(ctx_stack[ctx_stack_at], result, result_len);

	___tracy_emit_zone_end(ctx_stack[ctx_stack_at]);
	return TCL_OK;
}

static int
leave_all(ClientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
	if(objc != 1)
	{
		Tcl_WrongNumArgs(interp, 1, objv, "");
		return TCL_ERROR;
	}
	while(ctx_stack_at > 0)
	{
		--ctx_stack_at;
		if(ctx_stack_at >= 8192) continue;
		___tracy_emit_zone_end(ctx_stack[ctx_stack_at]);
	}
	return TCL_OK;
}

int
Profiling_Init(Tcl_Interp *interp)
{
	if(Tcl_InitStubs(interp, "8.6", 0) == NULL) return TCL_ERROR;
	if(Tcl_CreateNamespace(interp, "::profiling", NULL, NULL) == NULL) return TCL_ERROR;
	Tcl_CreateObjCommand(interp, "::profiling::enter", enter, NULL, NULL);
	Tcl_CreateObjCommand(interp, "::profiling::leave", leave, NULL, NULL);
	Tcl_CreateObjCommand(interp, "::profiling::leaveAll", leave_all, NULL, NULL);
	return 0;
}
