/**
 * Thrown by the policy rule engine for unrecoverable evaluation faults
 * (unknown operator, malformed rule configuration). Never thrown for a
 * fact simply being absent — that is modeled as INDETERMINATE.
 */
public class PolicyEngineException extends Exception {}
